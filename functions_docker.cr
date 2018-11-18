module FunctionsDocker 
	extend self

	# returns an array with the concatenated docker ID and Names
	def get_container_list
	        puts "#{INFO} - Get list of containers..."
	        containers=`docker ps --all --format "{{.ID}} {{.Names}}"`.strip.split("\n")
	        if $?.exit_status != 0
	                puts "#{FAIL} - Sorry, something went wrong while trying to get the container listing"
	                exit 1
	        else
	                puts "#{OK} - Got #{containers.size} containers."
	        end
		return containers
	end


end
