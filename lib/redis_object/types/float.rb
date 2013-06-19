module Seabright
	module Types
		module FloatType
			
			def format_float(val)
				val ? Float(val) : nil
			end
			alias_method :score_float, :format_float
			
		end
		
		register_type :Float
		
	end
end