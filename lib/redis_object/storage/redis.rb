module Seabright
	module Storage
		class Redis < Adapter
			
			def method_missing(sym, *args, &block)
				puts "[Storage::Redis] #{sym}(#{args.inspect.gsub(/\[|\]/m,'')})" if Debug.verbose?
				begin
					connection.send(sym,*args, &block)
				rescue ::Redis::InheritedError => err
					puts "Rescued: #{err.inspect}" if DEBUG
					reset
					connection.send(sym,*args, &block)
				end
			end
			
			def new_connection
				require 'redis'
				# puts "Connecting to Redis with: #{config_opts(:path, :db, :password).inspect}" if DEBUG
				::Redis.new(config_opts(:path, :db, :password))
			end
			
		end
	end
end