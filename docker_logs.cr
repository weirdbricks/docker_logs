require "db"
require "pg" #postgres
require "json"
require "toml" #reads our configuration files
require "./startup_checks.cr"
require "./docker_logs_startup_checks.cr"

OK   = "[  OK  ]"
INFO = "[ INFO ]"
FAIL = "[ FAIL ]"
SETTINGS_FILE = "./settings.toml"

##########################################################################################
# Include functions from files
##########################################################################################

# include functions from the ./startup_checks.cr file
include StartupChecks

# include functions from the ./docker_logs_startup_checks.cr file
include DockerLogsStartupChecks

##########################################################################################
# Startup checks
##########################################################################################

# the check_if_settings_file_exists function is in ./startup_checks.cr
check_if_settings_file_exists(SETTINGS_FILE)

puts "#{INFO} - Parsing \"#{SETTINGS_FILE}\" - \"settings\" table..."
SETTINGS    = TOML.parse_file(SETTINGS_FILE)["settings"].as(Hash)
PG_SETTINGS = TOML.parse_file(SETTINGS_FILE)["pg_settings"].as(Hash)
LOG_FILES   = TOML.parse_file(SETTINGS_FILE)["log_files"].as(Hash)

# the check_for_shell_command function is in ./startup_checks.cr
check_for_shell_command("logtail2")

# the get_hostname function is in ./startup_checks.cr
HOSTNAME = get_hostname

##########################################################################################
# Docker logs startup checks
##########################################################################################

if SETTINGS["PROCESS_DOCKER_LOGS"] == true

	check_for_shell_command("docker")

	# the check_if_the_docker_service_is_running function is in ./docker_logs_startup_checks.cr
	check_if_the_docker_service_is_running

	# the get_docker_root_dir function is in ./docker_logs_startup_checks.cr
	docker_Root_Dir=get_docker_root_dir

	# before we go any further let's make sure that we did get a value for the docker root directory
	puts "#{INFO} - Checking if we got the docker root directory..."
	if docker_Root_Dir.empty?
		puts "#{FAIL} - Sorry, I couldn't get the docker root directory"
		exit 1
	else
		puts "#{OK} - I got the docker root directory: \"#{docker_Root_Dir}\""
	end

else
	puts "#{INFO} - The \"PROCESS_DOCKER_LOGS\" option is set to \"false\" so I will not process any docker logs"
end

##########################################################################################
# Processing lines
##########################################################################################

# takes in a log file and the name of a docker container
# returns an array that includes:
# the temporary filename that contains the new lines (string)
# the number of those lines (integer)
def get_new_lines_from_file(log_filename,name)
	log_basename=File.basename(log_filename)
	`logtail2 -f #{log_filename} -o /dev/shm/#{log_basename}.offset > /tmp/#{log_basename}.tmp`
	if File.empty?("/tmp/#{log_basename}.tmp")
		puts "#{OK} - No new lines for container \"#{name}\""
		return [] of String
	else
		line_count=`wc -l /tmp/#{log_basename}.tmp | awk '{print $1}'`.to_i
		puts "#{OK} - #{line_count} new lines for container \"#{name}\""
		return ["/tmp/#{log_basename}.tmp",line_count]
	end
end

# this function takes the temporary filename created by logtail2 and 
# processes it line by line, adding lines to the database in a table
def process_file(file_to_process, lines_to_process, db, table_name)
	counter=0
	start_cycle=Time.now.to_unix_f
	File.each_line(file_to_process.to_s) do |line|
		counter=counter+1
		if (counter % 1000) == 0
			end_cycle=Time.now.to_unix_f
			cycle_time=end_cycle-start_cycle
			puts "Processing line #{counter} of #{lines_to_process} (#{((100/lines_to_process.to_f)*counter).round(1)}%) - Seconds: #{cycle_time.round(2)}"
			start_cycle=Time.now.to_unix_f
		end
		parsed_json=JSON.parse(line)
		time = parsed_json["time"]
		log  = parsed_json["log"]
		db.exec "insert into #{table_name} values ($1, $2)", log, time
	end
end

puts "#{INFO} - Check that you can connect to postgres..."
PG_USERNAME = PG_SETTINGS["PG_USERNAME"]
PG_PASSWORD = PG_SETTINGS["PG_PASSWORD"]
PG_DATABASE = PG_SETTINGS["PG_DATABASE"]
PG_HOSTNAME = PG_SETTINGS["PG_HOSTNAME"]
PG_PORT     = PG_SETTINGS["PG_PORT"]

begin
	db = DB.open "postgres://#{PG_USERNAME}:#{PG_PASSWORD}@#{PG_HOSTNAME}:#{PG_PORT}/#{PG_DATABASE}"
rescue
	puts "#{FAIL} - Sorry, Cannot connect to Postgres"
	exit 1
end

puts "#{OK} - Successfull connection to Postgres"

puts "#{INFO} - Getting the list of tables in the \"#{PG_DATABASE}\" database..."
existing_tables = db.query_all "SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname != 'pg_catalog' AND schemaname != 'information_schema'", as: String 

if existing_tables.size == 0
	puts "#{INFO} - No tables were found - this is probably the first run :)"
else
	puts "#{INFO} - #{existing_tables.size} tables were found - these are:"
	existing_tables.each do |table|
		puts "#{INFO} - #{table}"
	end
end

# we run this part only if the PROCESS_DOCKER_LOGS option
# in the settings file is set to true
if SETTINGS["PROCESS_DOCKER_LOGS"] == true 

	puts "#{INFO} - Get list of containers..."
	containers=`docker ps --all --format "{{.ID}} {{.Names}}"`.strip.split("\n")
	if $?.exit_status != 0
	        puts "#{FAIL} - Sorry, something went wrong while trying to get the container listing"
	        exit 1
	else
	        puts "#{OK} - Got #{containers.size} containers."
	end


	puts "#{INFO} - Getting the container logs..."
	containers.each do |container|
		id         = container.split(" ")[0]
		name       = container.split(" ")[1]
		full_id    = `docker inspect --format="{{.Id}}" #{id}`.strip
		table_name = "#{HOSTNAME}_#{name}"
		# "-" characters are not allowed in names, so we'll replace them with "_"
		table_name = table_name.gsub('-', "_")
		# and make sure it's downcased
		table_name = table_name.downcase
		if existing_tables.includes?(table_name)
			puts "#{OK} - The table \"#{table_name}\" already exists"
		else
			puts "#{INFO} - Creating the table \"#{table_name}\"..."
			db.exec "create table #{table_name} (name varchar(2000), ts timestamptz)"
		end

		log_filename="#{docker_Root_Dir}/containers/#{full_id}/#{full_id}-json.log"
		if File.file?(log_filename)
			puts "#{INFO} - Found the file \"#{log_filename}\""
			results=get_new_lines_from_file(log_filename,name)
	                next if results.none?

			file_to_process  = results[0]
			lines_to_process = results[1]
			process_file(file_to_process,lines_to_process,db,table_name)
			
		else
			puts "#{FAIL} - Sorry I could not find the file \"#{log_filename}\""
		end
	end

end
