
module Seabright
	module Storage
		class AWS
			
			def initialize(config={})
				Log.debug "Got config: '#{config.inspect}'"
				@config = config
			end
			
			def configure(conf)
				@config = conf
				reset
			end
			
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
			
			def reset
				@connection = nil
			end
			
			def connection
				@connection ||= new_connection
			end
			
			def new_connection
				require 'fog'
				require 'aws-sdk'
				
				opts = [:path, :db, :password].inject({}) {|a,k| 
					a[k] = @config[k]
					a
				}
				::Redis.new(opts)
			end
			
		end
	end
end