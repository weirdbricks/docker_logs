module DockerLogsStartupChecks
	extend self

	# check if the docker service is running
	def check_if_the_docker_service_is_running
		puts "#{INFO} - Check if the docker service is running..."
		`docker info >> /dev/null 2>&1`
		if $?.exit_status != 0
			puts "#{FAIL} - the docker service is not running"
			exit 1
		else
			puts "#{OK} - the docker service is running"
		end
	end

	# gets the docker root directory - that's where the containers live
	def get_docker_root_dir
		docker_root_dir=""
		docker_info=`docker info >> /dev/stdout 2>&1`.strip.split("\n")
		docker_info.each do |line|
			if line.includes?("Docker Root Dir:")
				docker_root_dir=line.split("Docker Root Dir:")[1].strip
			end
		end
		return docker_root_dir
	end

end