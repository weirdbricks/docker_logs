module FunctionsDatabase
	extend self

	# takes the pg_settings_hash as input, attempts to connect to postgres
	# and upon success returns the db object
	def connect_to_database(pg_settings)
		puts "#{INFO} - Check that you can connect to postgres..."
		pg_username = pg_settings["PG_USERNAME"]
		pg_password = pg_settings["PG_PASSWORD"]
		pg_database = pg_settings["PG_DATABASE"]
		pg_hostname = pg_settings["PG_HOSTNAME"]
		pg_port     = pg_settings["PG_PORT"]

		begin
		        db = DB.open "postgres://#{pg_username}:#{pg_password}@#{pg_hostname}:#{pg_port}/#{pg_database}"
		rescue
		        puts "#{FAIL} - Sorry, Cannot connect to Postgres"
		        exit 1
		end
		return db
	end

	# takes the db object and the name of our database and returns the an array of existing tables
	def get_list_of_existing_tables(db, pg_database)
		puts "#{INFO} - Getting the list of tables in the \"#{pg_database}\" database..."
		existing_tables = db.query_all "SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname != 'pg_catalog' AND schemaname != 'information_schema'", as: String

		if existing_tables.size == 0
		        puts "#{INFO} - No tables were found - this is probably the first run :)"
		else
		        puts "#{INFO} - #{existing_tables.size} tables were found - these are:"
		        existing_tables.each do |table|
		                puts "#{INFO} - #{table}"
		        end
		end
		return existing_tables
	end

	# create the table in the database if it doesn't already exist
	# needs the following parameters
	# the db object
	# the table name
	# the array of existign tables
	def create_table_if_not_there(db, table_name, existing_tables)
		if existing_tables.includes?(table_name)
                        puts "#{OK} - The table \"#{table_name}\" already exists"
                else
                        puts "#{INFO} - Creating the table \"#{table_name}\"..."
                        db.exec "create table #{table_name} (name varchar(10000), ts timestamptz)"
                end
	end

end
