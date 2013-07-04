module Seabright
	module Sanitization
		
		module ClassMethods
			
			def named_sanitization(name,*flds)
				named_sanitizations[name.to_sym] = flds
				add_sanitization_methods!
			end
			
			def add_sanitization_methods!
				return if @add_sanitization_methods
				self.class_eval do
					
					def sanitize_by_name!(name)
						if flds = self.class.named_sanitizations[name.to_sym]
							flog = Set.new
							flds.each do |fld|
								if is_set?(fld)
									unset(fld)
									flog << fld
								end
							end
							sanitize_log(:one_time,*flog)
						end
					end
					
				end
				@add_sanitization_methods = true
			end
			
			def named_sanitizations
				@named_sanitizations ||= {}
			end
			
		end
		
		def sanitize!(*flds)
			flog = Set.new
			flds.each do |fld|
				if is_set?(fld)
					unset(fld)
					flog << fld
				end
			end
			sanitize_log(:one_time,*flog)
		end
		
		def sanitize_log(name,*flds)
			set(:last_sanitized, Time.now)
		end
		
		def self.included(base)
			base.send(:date, :last_sanitized)
			base.extend(ClassMethods)
		end
		
	end
end
