module Seabright
	module References
		
		def ref_key(ident = nil)
			"#{hkey}:backreferences"
		end
		
		def reference(obj)
			name = obj.class.plname.underscore
			store.sadd hkey_col, name
			collections[name.to_s] ||= Seabright::Collection.load(name,self)
			collections[name.to_s] << obj.hkey
			obj.referenced_by self
		end
		alias_method :<<, :reference
		alias_method :push, :reference
		
		def referenced_by(obj)
			store.sadd(ref_key,obj.hkey)
		end
		
	end
end

# module Seabright
# 	module References
# 		
# 		def ref_key
# 			@ref_key ||= "#{hkey}:backreferences"
# 		end
# 		
# 		def nref_key
# 			@nref_key ||= "#{hkey}:named_references"
# 		end
# 		
# 		def reference(obj)
# 			name = obj.class.plname.downcase.to_sym
# 			store.sadd hkey_col, name
# 			@collections[name] ||= Seabright::Collection.load(name,self)
# 			@collections[name] << obj.hkey
# 			obj.referenced_by self
# 		end
# 		
# 		def reference_as(ky,obj)
# 			store.sadd(nref_key,ky)
# 			set(ky,obj.id)
# 		end
# 		
# 		def referenced_by(obj)
# 			store.sadd(ref_key,obj.hkey)
# 		end
# 		
# 		def is_named_reference?(ky)
# 			store.sismember(nref_key,ky)
# 		end
# 		
# 		def get(ky)
# 			is_named_reference?(ky) ? self.class.find_by_key(super(ky)) : super(ky)
# 		end
# 		
# 	end
# end