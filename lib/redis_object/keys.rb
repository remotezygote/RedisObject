module Seabright
	module Keys
		
		def key(ident = id)
			"#{self.class.cname}:#{clean_id(ident)}"
		end
		
		def reserve_key(ident = id)
			"#{key(ident)}_reserve"
		end
		
		def hkey(ident = id)
			"#{key(ident)}_h"
		end
		
		def ref_field_key(ident = id)
			"#{key(ident)}_ref_fields"
		end
		
		module ClassMethods
			
			def key(ident=nil)
				"#{cname}#{ident ? ":#{clean_id(ident)}" : ""}"
			end
			
			def reserve_key(ident=nil)
				"#{key(ident)}_reserve"
			end
			
			def hkey(ident = nil)
				"#{key(ident)}_h"
			end
			
			def ref_field_key(ident = nil)
				"#{key(ident)}_ref_fields"
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end