module Seabright
	module DefaultValues
		
		def get(k)
			if (d = self.class.default_vals[k.to_sym]) && !d.nil?
				return d unless is_set?(k)
			end
			super(k)
		end
		
		module ClassMethods
			
			def default_vals
				@default_vals ||= {}
			end
			
			def register_default(k,vl)
				default_vals[k.to_sym] = vl
			end
			alias_method :default_for, :register_default
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end