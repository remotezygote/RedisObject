module Seabright
	module Types
		module BooleanType
			
			def format_boolean(val)
				val=="true"
			end
			
			def save_boolean(val)
				val === true ? "true" : "false"
			end
			
			def score_boolean(val)
				val ? 1 : 0
			end
			
		end
		
		alias_type :Bool, :Boolean
		
	end
end