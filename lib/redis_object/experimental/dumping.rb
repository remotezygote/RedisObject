require 'psych'
require 'active_support/core_ext/time/calculations'

module Seabright
	class RedisObject
		
		def self.dump_everything(file=nil)
			out = {}
			ObjectSpace.enum_for(:each_object, class << RedisObject; self; end).each do |cls|
				unless cls == RedisObject
					out[cls.name] = {}
					out[cls.name][:objects] = cls.all.map do |obj|
						obj.full_hash_dump
					end
				end
			end
			Psych.dump(out)
		end
		
		def self.load_dump(str)
			Psych.load(str).each do |(k,v)|
				if klass = RedisObject.deep_const_get(k)
					if v[:objects]
						v[:objects].each do |o|
							load_object klass, o
						end
					end
				end
			end
		end
		
		def self.load_object(klass,pkt)
			Log.debug "Loading a #{klass.name}: #{pkt.inspect}"
			cols = nil
			pkt.delete(:collections).each do |col_name|
				if objs = pkt.delete(col_name.to_sym)
					cols ||= {}
					cols[col_name.to_sym] = objs
				end
			end
			obj = klass.create(pkt)
			if cols
				cols.each do |name,objs|
					Log.debug "  Loading in collected #{name}: #{objs.inspect}"
					obj.collect_type_by_key name, *objs
				end
			end
		end
		
	end
	
	module Dumping
		
		# def dump(file=nil)
		# 	if file && File.exists?(file)
		# 		# 
		# 	else
		# 		self.to_yaml
		# 	end
		# end
		
		def full_hash_dump
			store.hgetall(hkey).inject({}) {|acc,(k,v)| acc[k.to_sym] = enforce_format(k,v); acc }.merge(dump_collections)
		end
		
		def dump_collections
			cols = []
			collections.inject({}) do |acc,(k,v)|
				acc[k.to_sym] = v.map {|o| o.hkey }
				cols << k
				acc
			end.merge(collections: cols)
		end
		
		def to_json
			Yajl::Encoder.encode(full_hash_dump)
		end
		
		def to_yaml
			Psych.dump(full_hash_dump)
		end
		alias_method :to_yml, :to_yaml
		
		module ClassMethods
			
			
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end