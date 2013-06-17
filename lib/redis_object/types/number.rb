module Seabright
	module Types
		module NumberType
			
			def format_number(val)
				val.to_i
			end
			
			def score_number(val)
				Float(val)
			end
			
		end
		
		register_type :Number
		alias_type :Int, :Number
		
	end
end