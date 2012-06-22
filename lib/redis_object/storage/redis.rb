module Seabright
	module Storage
		class Redis < Adapter
			
			def method_missing(sym, *args, &block)
				puts "[Storage::Redis] #{sym}(#{args.inspect.gsub(/\[|\]/m,'')})" if Debug.verbose?
				connection.send(sym,*args)
			end
			
			private
			
			def new_connection
				require 'redis'
				opts = [:path, :db, :password].inject({}) {|a,k|
					a[k] = @config[k]
					a
				}
				::Redis.new(opts)
			end
			
		end
	end
end