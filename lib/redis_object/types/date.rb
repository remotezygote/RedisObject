module Seabright
	module Types
		module DateType
			
			def format_date(val)
				begin
					val.is_a?(DateTime) || val.is_a?(Date) || val.is_a?(Time) ? val : ( val.is_a?(String) ? DateTime.parse(val) : nil )
				rescue StandardError => e
					puts "Could not parse value as date using Date.parse. Returning nil instead. Value: #{val.inspect}\nError: #{e.inspect}" if DEBUG
					nil
				end
			end
			
			def score_date(val)
				val.to_time.to_i
			end
			
		end
		
		register_type :Date
		
	end
end