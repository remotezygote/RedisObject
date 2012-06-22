module Seabright
	module Storage
		class Adapter
		
			def initialize(config={})
				@config = config
			end
		
			def configure(conf)
				@config = conf
				reset
			end
		
			private
		
			def reset
				@connections.each_index do |i|
					@connections[i] = nil
				end
			end
		
			def connection(num=0)
				@connections ||= []
				@connections[num] ||= new_connection
			end
		
			def new_connection
				true
			end
		
			# def set
			# 	
			# end
			# 
			# def sadd
			# 	
			# end
			# 
			# def del
			# 	
			# end
			# 
			# def srem
			# 	
			# end
			# 
			# def smembers
			# 	
			# end
			# 
			# def exists
			# 	
			# end
			# 
			# def hget
			# 	
			# end
			# 
			# def hset
			# 	
			# end
		
		end
	end
end