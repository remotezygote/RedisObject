module Seabright
	module Triggers
		
		module ClassMethods
			
			def trigger_on_set(fld,actn)
				field_triggers[fld.to_sym] = actn.to_sym
				intercept_sets_for_triggers!
			end
			
			def intercept_sets_for_triggers!
				return if @intercepted_sets_for_triggers
				self.class_eval do
					alias_method :untriggered_set, :set unless method_defined?(:untriggered_set)
					def set(k,v)
						untriggered_set(k,v)
						unless self.class.untriggerables.include?(k)
							if self.class.field_triggers[k.to_sym]
								send(self.class.field_triggers[k.to_sym],k,v)
							end
							self.class.update_triggers.each do |actn|
								send(actn.to_sym,k,v)
							end
						end
					end
					alias_method :untriggered_setnx, :setnx unless method_defined?(:untriggered_setnx)
					def setnx(k,v)
						ret = untriggered_setnx(k,v)
						unless self.class.untriggerables.include?(k)
							if self.class.field_triggers[k.to_sym]
								send(self.class.field_triggers[k.to_sym],k,v)
							end
							self.class.update_triggers.each do |actn|
								send(actn.to_sym,k,v)
							end
						end
						ret
					end
					
				end
				@intercepted_sets_for_triggers = true
			end
			
			def intercept_reference_for_triggers!
				return if @intercepted_reference_for_triggers
				self.class_eval do
					alias_method :untriggered_reference, :reference unless method_defined?(:untriggered_reference)
					def reference(obj)
						untriggered_reference(obj)
						self.class.reference_triggers.each do |actn|
							send(actn.to_sym,obj)
						end
					end
				end
				@intercepted_reference_for_triggers = true
			end
			
			def untriggerables
				@untriggerables ||= [:updated_at,:created_at]
			end
			
			def field_triggers
				@field_triggers ||= {}
			end
			
			def trigger_on_update(actn)
				update_triggers << actn.to_sym
				intercept_sets_for_triggers!
			end
			
			def update_triggers
				@update_triggers ||= Set.new
			end
			
			def trigger_on_reference(actn)
				reference_triggers << actn.to_sym
				intercept_reference_for_triggers!
			end
			
			def reference_triggers
				@reference_triggers ||= Set.new
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end
