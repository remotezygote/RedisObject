module Seabright
	module Types
		module ArrayType
			
			def format_array(val)
				return val if val.is_a?(Array)
				val ? Yajl::Parser.new(:symbolize_keys => true).parse(val) : []
			end
			
			def save_array(val)
				return val if val.is_a?(String)
				Yajl::Encoder.encode(val)
			end
			
		end
		
		register_type :Array
		
	end
end