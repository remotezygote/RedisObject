module Seabright
	module Types
		module NumberType
			
			def format_number(val)
				val ? val.to_i : nil
			end
			
			def score_number(val)
				Float(val || 0.0)
			end
			
		end
		
		register_type :Number
		alias_type :Int, :Number
		
	end
end