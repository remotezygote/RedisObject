module Seabright
	class RedisObject
		
		def self.store(id=store_name)
			adapters[id] ||= Seabright::Storage.const_get(adapter(id)).new(config(id))
		end
		
		def self.configure_store(conf,id=store_name,*ids)
			configs[id] = conf
			ids.each do |i|
				configs[i] = conf
			end
			store(id)
		end
		
		def self.reconnect!
			adapters.each do |k,v|
				v.reconnect!
			end
		end
		
		def self.adapters
			@@adapters ||= {}
		end
		
		def self.adapter(id=store_name)
			@adapter ||= (config(id) && config(id)[:adapter].to_sym) || :Redis
		end
		
		def self.store_name
			@store_name ||= :global
		end
		
		def self.configs
			@@conf ||= {}
		end
		
		def self.config(id=store_name)
			configs[id]
		end
		
		def self.stores
			adapters
		end
		
		def self.dump_stores_to_files(path)
			raise "Directory does not exist!" unless Dir.exists?(File.dirname(path))
			adapters.each do |name,adptr|
				if adptr.respond_to? :dump_to_file
					Log.info "Dumping #{name} into #{path}/#{name.to_s}.dump"
					adptr.dump_to_file("#{path}/#{name.to_s}.dump")
				end
			end
		end
		
		def self.restore_stores_from_files(path)
			raise "Directory does not exist!" unless Dir.exists?(File.dirname(path))
			Dir.glob(path + "/*.dump").each do |file|
				name = file.gsub(/\.[^\.]+$/,'').gsub(/.*\//,'').to_sym
				if (stor = store(name)) && stor.respond_to?(:restore_from_file)
					Log.info "Restoring #{name} from #{file}"
					stor.restore_from_file(file)
				end
			end
		end
		
	end
	
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
			
			def use_store(id)
				raise "Cannot use non-existent store: #{id}" unless RedisObject.store(id.to_sym)
				@store_name = id.to_sym
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end