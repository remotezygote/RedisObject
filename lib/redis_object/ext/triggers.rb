module Seabright
	module Triggers
		
		def set(k,v)
			super(k,v)
			if self.class.field_triggers[k.to_sym]
				send(self.class.field_triggers[k.to_sym],k,v)
			end
			self.class.update_triggers.each do |actn|
				send(actn.to_sym,k,v)
			end
		end
		
		module ClassMethods
			
			def trigger_on_set(fld,actn)
				field_triggers[fld.to_sym] = actn.to_sym
			end
			
			def field_triggers
				@field_triggers ||= {}
			end
			
			def trigger_on_update(actn)
				update_triggers.push actn.to_sym
			end
			
			def update_triggers
				@update_triggers ||= []
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end