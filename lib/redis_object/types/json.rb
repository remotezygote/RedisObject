module Seabright
	module Types
		module JsonType
			
			def format_json(val)
				Yajl::Parser.new(:symbolize_keys => true).parse(val)
			end
			
			def save_json(val)
				Yajl::Encoder.encode(val)
			end
			
		end
	end
end