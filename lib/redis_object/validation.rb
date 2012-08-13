module Seabright
	
	module Validation
		
		def valid?
			ret = true
			errors = []
			self.class.required_fields.each do |k|
				unless is_valid?(k)
					errors.push "#{k} is not valid and is needed to process."
					ret = false
				end
			end
			self.class.required_collections.each do |k|
				unless has_collection?(k)
					errors.push "Need a #{k} collection to proceed."
					ret = false
				end
			end
			ret
		end
		
		def is_set?(k)
			store.hexists(hkey,k)
		end
		
		def is_valid?(k)
			return false unless is_set?(k)
			return true unless validations[k]
			if val = get(k)
				case validations[k].class
				when Regexp
					return false unless validations[k].match(val)
				when Array
					return false unless validations[k].include?(val)
				else
					if validations[k].class == Class
						return false unless val.class == validations[k]
					end
				end
			end
			true
		end
		
		def validations
			@validations ||= self.class.validations
		end
		
		module ClassMethods
			
			def require_field(*args)
				args.each do |k|
					required_fields.push k.to_sym
				end
			end
			alias_method :require_fields, :require_field
			
			def require_collection(*args)
				args.each do |k|
					required_collections.push k.to_sym
				end
			end
			alias_method :require_collections, :require_collection
			
			def required_collections
				@required_cols ||= []
			end
			
			def required_fields
				@required ||= []
			end
			
			def validate(k,rl)
				validations[k] = rl
			end
			
			def validations
				@validations ||= {}
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
	
end