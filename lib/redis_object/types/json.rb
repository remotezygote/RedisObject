module Seabright
	module Types
		module JsonType
			
			def format_json(val)
				return val unless val.is_a?(String)
				val ? Yajl::Parser.new(:symbolize_keys => true).parse(val) : nil
			end
			
			def save_json(val)
				Yajl::Encoder.encode(val)
			end
			
		end
		
		register_type :Json
		
	end
end