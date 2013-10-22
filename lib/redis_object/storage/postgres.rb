module Seabright
	module Storage
		class Postgres < Adapter
			
			def new_connection
				# Should create a new connection to the storage service
				# :adapter=>'postgres', :host=>'localhost', :database=>'blog', :user=>'user', :password=>'password'
				db = Sequel.connect(config_opts(:adapter, :host, :database, :user, :password))
				db.extension :pg_array
				db.extension :pg_array_ops
				db.extension :pg_hstore
				db.extension :pg_hstore_ops
				db
			end
			
			def self.base_object
				BasePostgresObject
			end
			
			module BasePostgresObject
				
				def table
					self.class.table
				end
				
				def record
					@record ||= lambda {
						t = table.where(id: id)
						if t.count < 1
							table.insert(id: id)
						end
						table.where(id: id)
					}.call
				end
				
				def _save
					# Saves the current state to the adapter
						# store.sadd(self.class.plname, key)
						# store.del(reserve_key)
				end
				
				def _delete!
					# Delete it
						# store.del key
						# store.del hkey
						# store.del reserve_key
						# store.srem(self.class.plname, key)
				end
				
				def raw
					# Dump a hash of its keys/values
						# store.hgetall(hkey).inject({}) do |acc,(k,v)|
						# 	acc[k.to_sym] = enforce_format(k,v)
						# 	acc
						# end
				end
				
				def _get(k)
					# Get a vlue stored at this object's <k>
						# store.hget(hkey, k.to_s)
					record.where("data ? :key", key: k)
				end
				
				def _is_set?(k)
					# Does this object have <k> set?
						# store.hexists(hkey, k.to_s)
				end
				
				def _mset(dat)
					# Multi-set
						# store.hmset(hkey, *(dat.inject([]){|acc,(k,v)| acc << [k,v] }.flatten))
					table.insert(data: dat.hstore)
				end
				
				def _set(k,v)
					# Just set this objects' <k> to <v>
					table.insert(data: { k => v }.hstore)
				end
				
				def _set_ref(k,v)
					# Set this object's <k> to ref the key of object <v>
					# store.hset(hkey, k.to_s, v.hkey)
					table.insert(data: { k => v.hkey }.hstore)
				end
				
				def _track_ref_key(k)
					# Track <k> on this object as a reference
						# store.sadd(ref_field_key, k.to_s)
				end
				
				def _is_ref_key?(k)
					# Is <k> on this object a reference?
						# store.sismember(ref_field_key,k.to_s)
				end
				
				def _setnx(k,v)
					# Set <k> to <v> on this object only if not already set
						# store.hsetnx(hkey, k.to_s, v.to_s)
				end
				
				def _unset(*k)
					# Unset <*k> on this object
						# store.hdel(hkey, k.map(&:to_s))
				end
				
				# Collections
				def remove_collection!(name)
					# Remove a collection from this object - it simply no longer knows about it
						# store.srem hkey_col, name
				end
				
				def referenced_by(obj)
					# Store a backreference to <obj>, which has a direct reference to this object
						# store.sadd(ref_key,obj.hkey)
				end
				
				def backreference_keys
					# A list of objects that reference this object
						# store.smembers(ref_key)
				end
				
				def collection_names
					# A list of this object's known collections
						# @collection_names ||= store.smembers(hkey_col)
				end
				
				def track_collection(name)
					# Track a new collection on this object
						# store.sadd hkey_col, name
				end
				
				module ClassMethods
					
					def table
						@table ||= get_table || create_table
					end
					
					def table_identifier
						self.name.split('::').last.pluralize.underscore.to_sym
					end
					
					def get_table
						store[table_identifier]
					end
					
					def create_table
						store.create_table table_identifier do
							primary_key :id
							hstore :data
							array :collections
							array :ref_keys
						end
						store[table_identifier]
					end
					
					def reserve(k)
						# Reserve an id
							# store.set(reserve_key(k),Time.now.to_s)
					end
					
					def all_keys
						# A list of all the objects we know about
							# store.smembers(plname)
					end
					
					def untrack_key(member)
						# Forget about a key (like a delete)
							# store.srem(plname,member)
					end
					
					def match_keys(pkt)
						# Gets a list of keys that match the packet
					end
					
					def grab_id(ident)
						# Get object at <ident>
							# store.exists(self.hkey(ident.to_s)) ? self.new(ident.to_s) : nil
					end
					
					def exists?(ident)
						# Object exists at <ident>?
							# store.exists(self.hkey(ident)) || store.exists(self.reserve_key(ident))
					end
					
					def find_by_key(k)
						# Get object at <k>, regardless of what it is
							# if store.exists(k) && (cls = store.hget(k,:class))
							# 	return deep_const_get(cls.to_sym,Object).new(store.hget(k,id_sym(cls)))
							# end
							# nil
					end
					
					# Collections stuff
					def remove_collection!(name)
						# Remove a collection from this object - it simply no longer knows about it
							# store.srem hkey_col, name
					end
					
					def referenced_by(obj)
						# Store a backreference to <obj>, which has a direct reference to this object
							# store.sadd(ref_key,obj.hkey)
					end
					
					def backreference_keys
						# A list of objects that reference this object
							# store.smembers(ref_key)
					end
					
					def collection_names
						# A list of this object's known collections
							# @collection_names ||= store.smembers(hkey_col)
					end
					
					def track_collection(name)
						# Track a new collection on this object
							# store.sadd hkey_col, name
					end
					
					def collection_class
						# The class to use as collector (should include basic Collection stuff)
							# Seabright::Storage::TemplateAdapter::Collection
					end
					
				end
				
				def self.included(base)
					base.extend ClassMethods
				end
				
			end
			
			class Collection < Array
				
				class << self
					
				end
				
			end
			
		end
		
	end
end