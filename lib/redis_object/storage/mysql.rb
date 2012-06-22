module Seabright
	module Storage
		class MySQL
			
			def set
				
			end
			
			def sadd
				
			end
			
			def del
				
			end
			
			def srem
				
			end
			
			def smembers
				
			end
			
			def exists
				
			end
			
			def hget
				
			end
			
			def hset
				
			end
			
			private
			
			def connection(num=0)
				require 'mysql'
				@connections ||= []
				@connections[num] ||= MySQL.new
			end
			
		end
	end
end