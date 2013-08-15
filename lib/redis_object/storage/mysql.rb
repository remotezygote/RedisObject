module Seabright
	module Storage
		class Mysql < Adapter
			
			def self.base_object
				BaseRedisObject
			end
			
			class MethodNotImplemented < StandardError; end
			
			def method_missing(sym, *args, &block)
				raise MethodNotImplemented
			end
			
			def new_connection
				require 'mysql'
				::MySQL.new(config_opts(:path, :db, :password, :host, :port, :timeout, :tcp_keepalive))
			end
			
			module BaseMysqlObject
				
				def _save
					store.sadd(self.class.plname, key)
					store.del(reserve_key)
				end
				
				def _delete!
					store.del key
					store.del hkey
					store.del reserve_key
					store.srem(self.class.plname, key)
				end
				
				def raw
					store.hgetall(hkey).inject({}) do |acc,(k,v)|
						acc[k.to_sym] = enforce_format(k,v)
						acc
					end
				end
				
				def _get(k)
					store.hget(hkey, k.to_s)
				end
				
				def _is_set?(k)
					store.hexists(hkey, k.to_s)
				end

				def _mset(dat)
					store.hmset(hkey, *(dat.inject([]){|acc,(k,v)| acc << [k,v] }.flatten))
				end
				
				def _set(k,v)
					store.hset(hkey, k.to_s, v.to_s)
				end

				def _set_ref(k,v)
					store.hset(hkey, k.to_s, v.hkey)
				end

				def _track_ref_key(k)
					store.sadd(ref_field_key, k.to_s)
				end

				def _is_ref_key?(k)
					store.sismember(ref_field_key,k.to_s)
				end
				
				def _setnx(k,v)
					store.hsetnx(hkey, k.to_s, v.to_s)
				end
				
				def _unset(*k)
					store.hdel(hkey, k.map(&:to_s))
				end
				
				# Collections
				def remove_collection!(name)
					store.srem hkey_col, name
				end
				
				def referenced_by(obj)
					store.sadd(ref_key,obj.hkey)
				end
				
				def backreference_keys
					store.smembers(ref_key)
				end
				
				def collection_names
					@collection_names ||= store.smembers(hkey_col)
				end
				
				def track_collection(name)
					store.sadd hkey_col, name
				end
				
				module ClassMethods
					
					def reserve(k)
						store.set(reserve_key(k),Time.now.to_s)
					end
					
					def all_keys
						store.smembers(plname)
					end
					
					def untrack_key(member)
						store.srem(plname,member)
					end
					
					def recollect!
						store.keys("#{name}:*_h").each do |ky|
							store.sadd(plname,ky.gsub(/_h$/,''))
						end
					end
					
					NilPattern = 'nilpattern:'
					
					RedisObject::ScriptSources::Matcher = "local itms = redis.call('SMEMBERS',KEYS[1])
						local out = {}
						local val
						local pattern
						for i, v in ipairs(itms) do
							val = redis.call('HGET',v..'_h',ARGV[1])
							if val then
								if ARGV[2]:find('^pattern:') then
									pattern = ARGV[2]:gsub('^pattern:','')
									if val:match(pattern) ~= nil then
										table.insert(out,itms[i])
									end
								else
									if val == ARGV[2] then
										table.insert(out,itms[i])
									end
								end
							else
								if ARGV[2] == '#{NilPattern}' then
									table.insert(out,itms[i])
								end
							end
						end
						return out".gsub(/\t/,'').freeze

					RedisObject::ScriptSources::MultiMatcher = "local itms = redis.call('SMEMBERS',KEYS[1])
						local out = {}
						local matchers = {}
						local matcher = {}
						local mod
						for i=1,#ARGV do
							mod = i % 2
							if mod == 1 then
								matcher[1] = ARGV[i]
							else
								matcher[2] = ARGV[i]
								table.insert(matchers,matcher)
								matcher = {}
							end
						end
						local val
						local good
						local pattern
						for i, v in ipairs(itms) do
							good = true
							for n=1,#matchers do
								val = redis.call('HGET',v..'_h',matchers[n][1])
								if val then
									if matchers[n][2]:find('^pattern:') then
										pattern = matchers[n][2]:gsub('^pattern:','')
										if val:match(pattern) then
											good = good
										else
											good = false
										end
									else
										if val ~= matchers[n][2] then
											good = false
										end
									end
								else
									if matchers[n][2] == '#{NilPattern}' then
										good = true
									else
										good = false
									end
								end
							end
							if good == true then
								table.insert(out,itms[i])
							end
						end
						return out".gsub(/\t/,'').freeze
					
					def match_keys(pkt)
						mtchr = pkt.keys.count > 1 ? :MultiMatcher : :Matcher
						pkt = pkt.flatten.map do |i|
							case i
							when Regexp
								convert_regex_to_lua(i)
							when NilClass
								NilPattern
							else
								i.to_s
							end
						end
						run_script(mtchr,[plname],pkt)
					end
					
					def convert_regex_to_lua(reg)
						"pattern:#{reg.source.gsub("\\","")}"
					end
					
					def grab_id(ident)
						store.exists(self.hkey(ident.to_s)) ? self.new(ident.to_s) : nil
					end
					
					def exists?(k)
						store.exists(self.hkey(k)) || store.exists(self.reserve_key(k))
					end
					
					def find_by_key(k)
						if store.exists(k) && (cls = store.hget(k,:class))
							return deep_const_get(cls.to_sym,Object).new(store.hget(k,id_sym(cls)))
						end
						nil
					end
					
					# Collections
					def remove_collection!(name)
						store.srem hkey_col, name
					end
					
					def referenced_by(obj)
						store.sadd(ref_key,obj.hkey)
					end
					
					def backreference_keys
						store.smembers(ref_key)
					end
					
					def collection_names
						@collection_names ||= store.smembers(hkey_col)
					end
					
					def track_collection(name)
						store.sadd hkey_col, name
					end
					
					def collection_class
						Seabright::Storage::Redis::Collection
					end
					
				end
				
				def self.included(base)
					base.send(:include, Seabright::CachedScripts)
					base.extend ClassMethods
				end
				
			end
			
			class Collection < Array
				
				include Seabright::Collection
				include Seabright::CachedScripts
				
				def temp_key
					"#{key}::zintersect_temp::#{self.class.class_const_for(@name,@owner).new_id(4)}"
				end
				
				RedisObject::ScriptSources::FwdScript = "redis.call('ZINTERSTORE', KEYS[1], 2, KEYS[2], KEYS[3], 'WEIGHTS', 1, 0)\nlocal keys = redis.call('ZRANGE', KEYS[1], 0, KEYS[4])\nredis.call('DEL', KEYS[1])\nreturn keys".freeze
				RedisObject::ScriptSources::RevScript = "redis.call('ZINTERSTORE', KEYS[1], 2, KEYS[2], KEYS[3], 'WEIGHTS', 1, 0)\nlocal keys = redis.call('ZREVRANGE', KEYS[1], 0, KEYS[4])\nredis.call('DEL', KEYS[1])\nreturn keys".freeze
				
				def keys_by_index(idx,num=-1,reverse=false)
					run_script(reverse ? :RevScript : :FwdScript, [temp_key, index_key(idx), key, num])
				end
				
				def _delete(k)
					store.zrem(key,k)
				end
				
				def clear!
					store.zrem(key,self.join(" "))
				end
				
				def _concat(k)
					store.zadd(key,store.zcount(key,"-inf", "+inf"),k)
				end
				
				class << self
					
					def keys_for(obj,name,owner)
						class_const_for(name,owner).store.zrange(obj.key,0,-1)
					end
					
				end
				
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
				
				new_class = RedisObject.deep_const_get(new_name.to_sym)
				
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
					hdel("#{key}_h", new_class.id_sym(old_name))
					hset("#{key}_h", new_class.id_sym(new_name), key.sub(/^#{old_name}:/,''))
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