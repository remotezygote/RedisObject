module Seabright
	module Indices
		
		def index_key(idx)
			self.class.index_key(idx)
		end
		
		module ClassMethods
			
			def intercept_sets_for_indices!
				return if @intercepted_sets_for_indices
				self.class_eval do
					
					def indexed_set_method(meth,k,v)
						ret = send("unindexed_#{meth}".to_sym,k,v)
						if self.class.has_index?(k)
							set_index k, v, hkey
						end
						if self.class.has_sort_index?(k)
							set_sort_index k, v, hkey
						end
						ret
					end
					
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
					
					alias_method :unindexed_set, :set unless method_defined?(:unindexed_set)
					def set(k,v)
						indexed_set_method(:set,k,v)
					end
					
					alias_method :unindexed_setnx, :setnx unless method_defined?(:unindexed_setnx)
					def setnx(k,v)
						indexed_set_method(:setnx,k,v)
					end
					
					alias_method :unindexed_mset, :mset unless method_defined?(:unindexed_mset)
					def mset(dat)
						dat.select {|k,v| self.class.has_index?(k) }.each do |k,v|
							set_index k, v, hkey
						end
						dat.select {|k,v| self.class.has_sort_index?(k) }.each do |k,v|
							set_sort_index k, v, hkey
						end
						unindexed_mset(dat)
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
				"#{self.plname}::#{k}::field_index::#{v}"
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
				store.keys(index_key(k,"*")).each do |k|
					store.del k
				end
				all.each do |obj|
					if v = obj.get(k)
						set_index(k, v, obj.hkey)
					end
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