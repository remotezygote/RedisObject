module Seabright
	module Types
		
		def enforce_format(k,v)
			if v && fmt = self.class.field_formats[k.to_sym] 
				send(fmt,v)
			else 
				v
			end
		end
		
		def save_format(k,v)
			v && (fmt = self.class.save_formats[k.to_s.gsub(/\=$/,'').to_sym]) ? send(fmt,v) : v
		end
		
		def format_date(val)
			val.instance_of?(DateTime) ? val : DateTime.parse(val)
		end
		
		def format_array(val)
			eval val
		end
		
		def format_number(val)
			val.to_i
		end
		
		def format_json(val)
			require 'yajl'
			Yajl::Parser.new(:symbolize_keys => true).parse(val)
		end
		
		def save_json(val)
			require 'yajl'
			Yajl::Encoder.encode(val)
		end
		
		def format_boolean(val)
			val=="true"
		end
		
		def get(k)
			enforce_format(k,super(k))
		end
		
		def set(k,v)
			super(k,save_format(k,v))
		end
		
		module ClassMethods
			
			def date(k)
				field_formats[k] = :format_date
			end
			
			def number(k)
				field_formats[k] = :format_number
			end
			
			def bool(k)
				field_formats[k] = :format_boolean
			end
			
			def array(k)
				field_formats[k] = :format_array
			end
			
			def json(k)
				field_formats[k] = :format_json
				save_formats[k] = :save_json
			end
			
			def field_formats
				@@field_formats ||= {}
			end
			
			def save_formats
				@@save_formats ||= {}
			end
			
			def register_format(k,fmt)
				send(fmt, k)
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end