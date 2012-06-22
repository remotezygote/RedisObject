module Seabright
	module Keys
		
		def key(ident = id, prnt = parent)
			"#{prnt ? prnt.class==String ? "#{prnt}:" : "#{prnt.key}:" : ""}#{self.class.cname}:#{ident.gsub(/^.*:/,'')}"
		end
		
		def reserve_key(ident = id,prnt=nil)
			"#{key(ident,prnt)}_reserve"
		end
		
		def hkey(ident = nil, prnt = nil)
			"#{key}_h"
		end
		
		module ClassMethods
			
			def key(ident, prnt = nil)
				"#{prnt ? prnt.class==String ? "#{prnt}:" : "#{prnt.key}:" : ""}#{cname}:#{ident.gsub(/^.*:/,'')}"
			end
			
			def reserve_key(ident, prnt = nil)
				"#{key(ident,prnt)}_reserve"
			end
			
			def hkey(ident = id, prnt = nil)
				"#{key(ident,prnt)}_h"
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end