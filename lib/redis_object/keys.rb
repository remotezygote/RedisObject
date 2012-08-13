module Seabright
	module Keys
		
		def key(ident = id)
			"#{self.class.cname}:#{ident.gsub(/^.*:/,'')}"
		end
		
		def reserve_key(ident = id)
			"#{key(ident)}_reserve"
		end
		
		def hkey(ident = nil)
			"#{key}_h"
		end
		
		module ClassMethods
			
			def key(ident)
				"#{cname}:#{ident.gsub(/^.*:/,'')}"
			end
			
			def reserve_key(ident)
				"#{key(ident)}_reserve"
			end
			
			def hkey(ident = id)
				"#{key(ident)}_h"
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end