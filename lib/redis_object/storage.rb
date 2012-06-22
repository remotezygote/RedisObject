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
				@@adapter = adp
			end
			
			def adapter
				@@adapter ||= config[:adapter].to_sym || :Redis
			end
			
			def store
				@@storage ||= const_get(adapter).new(config)
			end
			
			def configure_store(conf)
				@@conf = conf
			end
			
			def config
				@@conf ||= {}
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end