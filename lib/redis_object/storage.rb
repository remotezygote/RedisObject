module Seabright
	module Storage
		
		require 'redis_object/storage/adapter'
		autoload :Redis, 'redis_object/storage/redis'
		autoload :MySQL, 'redis_object/storage/mysql'
		
		def store
			self.class.store
		end
		
		module ClassMethods
			
			def set_storage(adp=adapter)
				@adapter = adp
			end
			
			def store(id=store_name)
				adapters[id] ||= const_get(adapter).new(config(id))
			end
			
			def configure_store(conf,id=store_name)
				configs[id] = conf
			end
			
			def use_store(id)
				raise "Cannot use non-existent store: #{id}" unless config(id)
				@store_name = id.to_sym
			end
			
			def reconnect!
				adapters.each do |k,v|
					v.reconnect!
				end
			end
			
			def adapters
				@@adapters ||= {}
			end
			
			def adapter
				@adapter ||= config[:adapter].to_sym || :Redis
			end
			
			def store_name
				@store_name ||= :global
			end
			
			def configs
				@@conf ||= {}
			end
			
			def config(id=store_name)
				configs[id]
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end