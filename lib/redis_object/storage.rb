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
			
			def configure_store(conf,id=store_name,*ids)
				configs[id] = conf
				ids.each do |i|
					configs[i] = conf
				end
				store(id)
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
			
			def stores
				adapters
			end
			
			def dump_stores_to_files(path)
				raise "Directory does not exist!" unless Dir.exists?(File.dirname(path))
				adapters.each do |name,adptr|
					if adptr.respond_to? :dump_to_file
						puts "Dumping #{name} into #{path}/#{name.to_s}.dump"
						adptr.dump_to_file("#{path}/#{name.to_s}.dump")
					end
				end
			end
			
			def restore_stores_from_files(path)
				raise "Directory does not exist!" unless Dir.exists?(File.dirname(path))
				Dir.glob(path + "/*.dump").each do |file|
					name = file.gsub(/\.[^\.]+$/,'').gsub(/.*\//,'').to_sym
					if (stor = store(name)) && stor.respond_to?(:restore_from_file)
						puts "Restoring #{name} from #{file}"
						stor.restore_from_file(file)
					end
				end
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end