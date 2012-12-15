module Seabright
	module Types
		
		def enforce_format(k,v)
			if v && fmt = self.class.field_formats[k.to_sym] 
				send(fmt,v)
			else 
				v
			end
		end
		
		def score_format(k,v)
			if v && fmt = self.class.score_formats[k.to_sym] 
				send(fmt,v)
			else 
				0
			end
		end
		
		def save_format(k,v)
			v && (fmt = self.class.save_formats[k.to_s.gsub(/\=$/,'').to_sym]) ? send(fmt,v) : v
		end
		
		def format_date(val)
			val.instance_of?(DateTime) ? val : DateTime.parse(val)
		end
		
		def score_date(val)
			val.to_time.to_i
		end
		
		def format_array(val)
			eval val
		end
		
		def format_number(val)
			val.to_i
		end
		
		def score_number(val)
			Float(val)
		end
		
		def format_float(val)
			Float(val)
		end
		alias_method :score_float, :format_float
		
		def format_json(val)
			Yajl::Parser.new(:symbolize_keys => true).parse(val)
		end
		
		def save_json(val)
			Yajl::Encoder.encode(val)
		end
		
		def format_boolean(val)
			val=="true"
		end
		
		def score_boolean(val)
			val ? 1 : 0
		end
		
		def get(k)
			enforce_format(k,super(k))
		end
		
		def mset(dat)
			dat.merge!(dat) {|k,v1,v2| save_format(k,v1) }
			super(dat)
		end
		
		def set(k,v)
			super(k,save_format(k,v))
		end
		
		module ClassMethods
			
			def date(k)
				field_formats[k] = :format_date
				score_formats[k] = :score_date
			end
			
			def number(k)
				field_formats[k] = :format_number
				score_formats[k] = :score_number
			end
			alias_method :int, :number
			
			def float(k)
				field_formats[k] = :format_float
				score_formats[k] = :score_float
			end
			
			def bool(k)
				field_formats[k] = :format_boolean
				score_formats[k] = :score_boolean
			end
			alias_method :boolean, :bool
			
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
			
			def score_formats
				@@score_formats ||= {}
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