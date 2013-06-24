module Seabright
	class RedisObject
		
		def self.dump_everything(file=nil)
			out = {}
			ObjectSpace.enum_for(:each_object, class << RedisObject; self; end).each do |cls|
				unless cls == RedisObject
					out[cls.name] = {}
					# cls.dump
					out[cls.name][:objects] = cls.all.map do |obj|
						obj.full_hash_dump
					end
				end
			end
			out.to_yaml
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
			require 'yaml'
			full_hash_dump.to_yaml
		end
		alias_method :to_yml, :to_yaml
		
		module ClassMethods
			
			
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end