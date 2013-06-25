module Seabright
	module Storage
		class Adapter
			
			def initialize(config={})
				configure config
			end
			
			def configure(conf)
				@config = conf
				reset
			end
			
			def config
				@config ||= {}
			end
			
			def config_opts(*opts)
				opts.inject({}) do |a,k|
					a[k] = config[k]
					a
				end
			end
			
			def reset
				connections.each_index do |i|
					connections[i] = nil
				end
			end
			alias_method :reconnect!, :reset
			
			def connection(num=0)
				connections[num] ||= new_connection
			end
			
			def connections
				@connections ||= []
			end
			
			def new_connection
			end
			
		end
	end
end