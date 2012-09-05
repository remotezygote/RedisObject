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
			
			def config
				@config ||= {}
			end
			
			private
			
			def config_opts(*opts)
				opts.inject({}) do |a,k|
					a[k] = config[k]
					a
				end
			end
			
			def reset
				@@connections.each_index do |i|
					@@connections[i] = nil
				end
			end
			
			def connection(num=0)
				@@connections ||= []
				@@connections[num] ||= new_connection
			end
			
			def new_connection
				true
			end
			
		end
	end
end