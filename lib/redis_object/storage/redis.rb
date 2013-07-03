module Seabright
	module Storage
		class Redis < Adapter
			
			def method_missing(sym, *args, &block)
				return super unless connection.respond_to?(sym)
				puts "[Storage::Redis] #{sym}(#{args.inspect.gsub(/\[|\]/m,'')})" if Debug.verbose?
				begin
					connection.send(sym,*args, &block)
				rescue ::Redis::InheritedError, ::Redis::TimeoutError => err
					puts "Rescued: #{err.inspect}" if DEBUG
					reset
					connection.send(sym,*args, &block)
				end
			end
			
			def new_connection
				require 'redis'
				puts "Connecting to Redis with: #{config_opts(:path, :db, :password, :host, :port, :timeout, :tcp_keepalive).inspect}" if DEBUG
				::Redis.new(config_opts(:path, :db, :password, :host, :port, :timeout, :tcp_keepalive))
			end
			
			DUMP_SEPARATOR = "---:::RedisObject::DUMP_SEPARATOR:::---"
			REC_SEPARATOR = "---:::RedisObject::REC_SEPARATOR:::---"
			
			def dump_to_file(file)
				File.open(file,'wb') do |f|
					keys = connection.send(:keys,"*")
					f.write keys.map {|k|
						if v = connection.dump(k)
							v.force_encoding(Encoding::BINARY)
							[k,v].join(DUMP_SEPARATOR)
						else
							""
						end
					}.join(REC_SEPARATOR)
				end
			end
			
			def restore_from_file(file)
				str = File.read(file)
				str.force_encoding(Encoding::BINARY)
				str.split(REC_SEPARATOR).each do |line|
					line.force_encoding(Encoding::BINARY)
					key, val = line.split(DUMP_SEPARATOR)
					connection.multi do
						connection.del key
						connection.restore key, 0, val
					end
				end
			end

			def rename_class old_name, new_name
				old_name = old_name.to_s#.split('::').last
				new_name = new_name.to_s#.split('::').last
				old_collection_name = old_name.split('::').last.underscore.pluralize
				new_collection_name = new_name.split('::').last.underscore.pluralize

				# references to type in collection data
				keys("#{old_name}:*:backreferences").each do |backref_key|
					smembers(backref_key).each do |hashref|
						# there are two referenes we need to fix: individual references to items
						# and lists of collection names.
						#
						# this updates the item references in collections
						backref = hashref.sub(/_h$/,'');
						old_collection = "#{backref}:COLLECTION:#{old_collection_name}"
						new_collection = "#{backref}:COLLECTION:#{new_collection_name}"
						zrange(old_collection, 0, 99999, withscores:true).each do |key, score|
							zadd(new_collection, score, key.sub(/^#{old_name}/, new_name))
						end
						del(old_collection)

						# this updates the lists of collection names
						collection_names = "#{hashref}:collections"
						smembers(collection_names).each do |collection_name|
							if collection_name == old_collection_name
								sadd(collection_names, new_collection_name)
								srem(collection_names, old_collection_name)
							end
						end
					end
					rename(backref_key, backref_key.sub(/^#{old_name}/, new_name))
				end

				# type-wide id index
				smembers(old_name.pluralize).each do |key|
					sadd(new_name.pluralize, key.sub(/^#{old_name}/, new_name))
					old_class = hget("#{key}_h", :class)
					old_key = hget("#{key}_h", :key)
					hset("#{key}_h", :class, new_name)
					hset("#{key}_h", :key, old_key.sub(/^#{old_name}/, new_name))
					hdel("#{key}_h", RedisObject.id_sym(old_name))
					hset("#{key}_h", RedisObject.id_sym(new_name), key.sub(/^#{old_name}:/,''))
				end
				del(old_name.pluralize)

				# column indexes
				keys("#{old_name.pluralize}::*").each do |old_index|
					new_index = old_index.sub(/^#{old_name.pluralize}/, new_name.pluralize)
					zrange(old_index, 0, 99999, withscores:true).each do |key, score|
						zadd(new_index, score, key.sub(/^#{old_name}/, new_name))
					end
					del(old_index)
				end

				# top-level keys
				keys("#{old_name}:*").each do |key|
					rename(key, key.sub(/^#{old_name}/, new_name))
				end
				keys("#{old_name.pluralize}:*").each do |key|
					rename(key, key.sub(/^#{old_name.pluralize}/, new_name.pluralize))
				end
			end
			
		end
	end
end
