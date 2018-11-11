require "db"
require "pg" #postgres
require "json"
require "poncho/parser" #reads .env files

OK   = "[  OK  ]"
INFO = "[ INFO ]"
FAIL = "[ FAIL ]"
SETTINGS_FILE = "./settings"

puts "#{INFO} - Check if we can get the \"#{SETTINGS_FILE}\" file..."
if File.file?(SETTINGS_FILE) 
	puts "#{OK} - The file \"#{SETTINGS_FILE}\" exists"
else
	puts "#{FAIL} - Sorry, I couldn't find the file \"#{SETTINGS_FILE}\"."
	exit 1
end

puts "#{INFO} - Parsing \"#{SETTINGS_FILE}\"..."
PG_SETTINGS = Poncho.from_file SETTINGS_FILE

def check_for_shell_command(some_command)
	puts "#{INFO} - Check if the \"#{some_command}\" command exists..."
	begin
		Process.run(some_command)
		puts "#{OK} - the \"#{some_command}\" command has been found"
	rescue
		puts "#{FAIL} - Sorry the \"#{some_command}\" command could not be found"
		exit 1
	end
end

check_for_shell_command("docker")
check_for_shell_command("logtail2")

puts "#{INFO} - Check if we can get the hostname..."
HOSTNAME=System.hostname
if HOSTNAME.empty? 
	puts "#{FAIL} - Sorry, I cannot get the hostname :("
	exit 1
else
	puts "#{OK} - I got the hostname: \"#{HOSTNAME}\""
end

puts "#{INFO} - Check if docker is running..."
begin
	args = ["info"]
	# stolen from https://stackoverflow.com/a/47051672
        output = IO::Memory.new
	Process.run("docker", args: args, output: output, error: output)
	puts "#{OK} - the docker service is running"
	# take the output from memory, cast it to a string, strip out
	# any whitespace and then split on a new line
	docker_info = output.to_s.strip.split("\n")
	docker_root_dir=""
	docker_info.each do |line|
		if line.includes?("Docker Root Dir:")
			docker_root_dir=line.split("Docker Root Dir:")[1].strip
		end
	end
rescue
	puts "#{FAIL} - Sorry the docker service is not running"
	exit 1
end

# before we go any further let's make sure that we did get a value for the docker root directory
puts "#{INFO} - Checking if we got the docker root directory..."
if docker_root_dir.empty?
	puts "#{FAIL} - Sorry, I couldn't get the docker root directory"
	exit 1
else
	puts "#{OK} - I got the docker root directory: \"#{docker_root_dir}\""
end

puts "#{INFO} - Get list of containers..."
containers=`docker ps --all --format "{{.ID}} {{.Names}}"`.strip.split("\n")
if $?.exit_status != 0
	puts "#{FAIL} - Sorry, something went wrong while trying to get the container listing"
else
	puts "#{OK} - Got #{containers.size} containers."
end

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
PG_PORT     = PG_SETTINGS["PG_PORT"].to_i

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

	log_filename="#{docker_root_dir}/containers/#{full_id}/#{full_id}-json.log"
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
