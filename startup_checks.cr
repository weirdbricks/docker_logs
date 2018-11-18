module StartupChecks
	extend self

	# check if we can get the settings file
	def check_if_settings_file_exists(settings_file)
		puts "#{INFO} - Check if we can get the \"#{settings_file}\" file..."
		if File.file?(settings_file)
		        puts "#{OK} - The file \"#{settings_file}\" exists"
		else
		        puts "#{FAIL} - Sorry, I couldn't find the file \"#{settings_file}\"."
		        exit 1
		end

	end

	# check if a some shell command exists
	# we use this to check if things like docker and logtail2 are installed
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

	# check if we can get the hostname from the local machine
	def get_hostname
		puts "#{INFO} - Check if we can get the hostname..."
		hostname=System.hostname
		if hostname.empty?
		        puts "#{FAIL} - Sorry, I cannot get the hostname :("
		        exit 1
		else
		        puts "#{OK} - I got the hostname: \"#{hostname}\""
		end
		return hostname
	end

end
