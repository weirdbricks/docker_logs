require "db"
require "pg" #postgres
require "json"
require "toml" #reads our configuration files
require "./startup_checks.cr"
require "./docker_logs_startup_checks.cr"
require "./functions_docker.cr"
require "./functions_database.cr"

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

# include functions from the ./functions_docker.cr file
include FunctionsDocker

# include functions from the ./functions_database.cr file
include FunctionsDatabase

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

	# the check_docker_root_dir function is in ./docker_logs_startup_checks.cr
	check_docker_root_dir(docker_Root_Dir)

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
def process_file(file_to_process, lines_to_process, db, table_name, log_type)
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

# connect to the database
# the connect_to_database function is in ./functions_database.cr
db = connect_to_database(PG_SETTINGS)

pg_database = PG_SETTINGS["PG_DATABASE"]
# the get_list_of_existing_tables function is in ./functions_database.cr
existing_tables = get_list_of_existing_tables(db, pg_database)

# we run this part only if the PROCESS_DOCKER_LOGS option
# in the settings file is set to true
if SETTINGS["PROCESS_DOCKER_LOGS"] == true 

	# the get_container_list function is in ./functions_docker.cr
	containers = get_container_list

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

		# the create_table_if_not_there function is in ./functions_database.cr
		create_table_if_not_there(db, table_name, existing_tables)

		log_filename="#{docker_Root_Dir}/containers/#{full_id}/#{full_id}-json.log"
		if File.file?(log_filename)
			puts "#{INFO} - Found the file \"#{log_filename}\""
			results=get_new_lines_from_file(log_filename,name)
	                next if results.none?

			file_to_process  = results[0]
			lines_to_process = results[1]
			log_type="docker"
			process_file(file_to_process,lines_to_process,db,table_name,log_type)
			
		else
			puts "#{FAIL} - Sorry I could not find the file \"#{log_filename}\""
		end
	end

end

if LOG_FILES.size > 0
	LOG_FILES.each do |name,filename|	
		log_type="syslog"
		puts name,filename
	end
end
