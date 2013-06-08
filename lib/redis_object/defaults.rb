module Seabright
	module DefaultValues
		
		module ClassMethods
			
			def default_vals
				@default_vals ||= {}
			end
			
			def intercept_for_defaults!
				return if @intercepted_for_defaults
				self.class_eval do
					
					alias_method :undefaulted_get, :get unless method_defined?(:undefaulted_get)
					def get(k)
						if !is_set?(k) && (d = self.class.default_vals[k.to_sym]) && !d.nil?
							return d
						end
						undefaulted_get(k)
					end
					
				end
				@intercepted_for_defaults = true
			end
			
			def register_default(k,vl)
				default_vals[k.to_sym] = vl
				intercept_for_defaults!
			end
			
			def default_for(k,vl)
				register_default k, vl
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end