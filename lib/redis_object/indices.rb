module Seabright
	
	class RedisObject
		
		def self.reindex_everything!
			RedisObject.child_classes.each do |cls|
				cls.reindex_all_indices!
			end
		end
		
	end
	
	module Indices
		
		def index_key(idx)
			self.class.index_key(idx)
		end
		
		module ClassMethods
			
			def intercept_sets_for_indices!
				return if @intercepted_sets_for_indices
				self.class_eval do
					
					def set_index(k,v,hkey)
						if cur = get(k)
							store.srem(self.class.index_key(k,cur), hkey)
						end
						store.sadd(self.class.index_key(k,v), hkey)
					end
					
					def set_sort_index(k,v,hkey)
						store.zrem(self.class.sort_index_key(k), hkey)
						store.zadd(self.class.sort_index_key(k), score_format(k,v), hkey)
					end
					
					filter_sets do |ob, k, v|
						if self.class.has_index?(k)
							obj.set_index k, v, obj.hkey
						end
						if self.class.has_sort_index?(k)
							obj.set_sort_index k, v, obj.hkey
						end
						[k, v]
					end
					
					filter_msets do |obj, dat|
						dat.each do |k,v|
							obj.set_index(k, v, obj.hkey) if self.class.has_index?(k)
						end
						dat.each do |k,v|
							obj.set_sort_index(k, v, obj.hkey) if self.class.has_sort_index?(k)
						end
						[k, v]
					end
					
				end
				@intercepted_sets_for_indices = true
			end
			
			def indexed(idx,num=-1,reverse=false)
				kys = store.send(reverse ? :zrevrange : :zrange, sort_index_key(idx), 0, num-1)
				out = ListEnumerator.new(kys) do |yielder|
					kys.each do |member|
						if a = self.find_by_key(member)
							yielder << a
						end
					end
				end
				if block_given?
					out.each do |itm|
						yield itm
					end
				else
					out
				end
			end
			
			def index_key(k,v)
				"#{self.plname}::field_index::#{k}::#{v}"
			end
			
			def sort_index_key(idx)
				"#{self.plname}::#{idx}"
			end
			
			def indices
				@@indices ||= Set.new
			end
			
			def sort_indices
				@@sort_indices ||= Set.new
			end
			
			def index(k)
				indices << k.to_sym
				intercept_sets_for_indices!
			end
			
			def sort_by(k)
				sort_indices << k.to_sym
				intercept_sets_for_indices!
			end
			
			def reindex(k)
				store.keys(index_key(k,"*")).each do |ik|
					store.del ik
				end
				all.each do |obj|
					if v = obj.get(k)
						obj.set_index(k, v, obj.hkey)
					end
				end
			end
			
			def reindex_all_indices!
				indices.each do |k|
					reindex(k)
				end
			end
			
			def has_index?(k)
				k and indices.include?(k.to_sym)
			end
			
			def has_sort_index?(k)
				k and sort_indices.include?(k.to_sym)
			end
			
			def latest
				indexed(:created_at,999,true).first
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end