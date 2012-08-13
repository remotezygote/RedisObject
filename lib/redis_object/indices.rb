module Seabright
	module Indices
		
		def save_indices
			# self.class.indices.each do |indx|
			# 	indx.each do |key,idx|
			# 		
			# 	end
			# end
			self.class.sort_indices.each do |idx|
				store.zadd(index_key(idx), send(idx).to_i, hkey)
			end
		end
		
		def index_key(idx,extra=nil)
			"#{self.class.plname}::#{idx}#{extra ? ":#{extra}" : ""}"
		end
		
		def save
			super
			save_indices
		end
		
		module ClassMethods
			
			def indexed(index,num=5,reverse=false)
				out = []
				store.send(reverse ? :zrevrange : :zrange, "#{self.plname}::#{index}", 0, num).each do |member|
					if a = self.find_by_key(member)
						out << a
					else
						# store.zrem(self.plname,member)
					end
				end
				out
			end
			
			def recently_created(num=5)
				self.indexed(:created_at,num,true)
			end
			
			def recently_updated(num=5)
				self.indexed(:updated_at,num,true)
			end
			
			def index(opts)
				indices << opts
			end
			
			def indices
				@@indices ||= []
			end
			
			def sort_indices
				@@sort_indices ||= []
			end
			
			def sort_by(k)
				sort_indices << k
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end