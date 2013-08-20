require 'psych'
require 'active_support/core_ext/time/calculations'

module Seabright
	class RedisObject
		
		def self.dump_everything(dump_format=:hash)
			out = {}
			ObjectSpace.enum_for(:each_object, class << RedisObject; self; end).each do |cls|
				unless cls == RedisObject
					out.merge! cls.dump_all(:hash)
				end
			end
			Dumping.format_dump out, dump_format
		end
		
		def self.load_dump(str,dump_format=:hash)
			case dump_format
			when :hash
				load_dump_from_hash str
			when :yaml, :yml
				load_dump_from_yaml str
			# JSON format is not ready yet!
			# when :json
			# 	load_dump_from_json str
			else
				raise "Unknown dump format."
			end
		end
		
		def self.load_data(dat)
			dat.each do |(k,v)|
				if klass = RedisObject.deep_const_get(k)
					if v[:objects]
						v[:objects].each do |o|
							load_object klass, o
						end
					end
				end
			end
		end
		
		def self.load_dump_from_yaml(str)
			load_data Psych.load(str)
		end
		
		def self.load_dump_from_hash(str)
			load_data str
		end
		
		# JSON format is not ready yet!
		# def self.load_dump_from_json(str)
		# 	load_data Yajl::Parser.new(symbolize_keys: true).parse(str)
		# end
		
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
		
		def self.format_dump(dump,format=:hash)
			case format
			when :hash
				return dump
			when :yaml, :yml
				return Psych.dump(dump)
			# JSON format is not ready yet!
			# when :json
			# 	return Yajl::Encoder.encode(dump)
			else
				return dump
			end
		end
		
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
			
			def dump_all(dump_format=:hash)
				out = {}
				out[self.name] = {}
				out[self.name][:objects] = all.map do |obj|
					obj.full_hash_dump
				end
				Dumping.format_dump out, dump_format
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end