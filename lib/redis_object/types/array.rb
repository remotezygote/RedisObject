module Seabright
	module Types
		module ArrayType
			
			def format_array(val)
				Yajl::Parser.new(:symbolize_keys => true).parse(val)
			end
			
			def save_array(val)
				Yajl::Encoder.encode(val)
			end
			
		end
	end
end