module Seabright
	module Indices
		
		# def save_indices
		# 	# self.class.indices.each do |indx|
		# 	# 	indx.each do |key,idx|
		# 	# 		
		# 	# 	end
		# 	# end
		# 	self.class.sort_indices.each do |idx|
		# 		store.zadd(index_key(idx), send(idx).to_i, hkey)
		# 	end
		# end
		
		def index_key(idx)
			self.class.index_key(idx)
		end
		
		# def save
		# 	super
		# 	save_indices
		# end
		
		def mset(dat)
			super(dat)
			dat.select {|k,v| self.class.has_sort_index?(k) }.each do |k,v|
				store.zadd(index_key(k), score_format(k,v), hkey)
			end
		end
		
		def set(k,v)
			super(k,v)
			if self.class.has_sort_index?(k)
				store.zadd(index_key(k), score_format(k,v), hkey)
			end
		end
		
		module ClassMethods
			
			def indexed(idx,num=-1,reverse=false)
				out = Enumerator.new do |yielder|
					store.send(reverse ? :zrevrange : :zrange, index_key(idx), 0, num).each do |member|
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
			
			def index_key(idx)
				"#{self.plname}::#{idx}"
			end
			
			# def index(opts)
			# 	indices << opts
			# end
			# 
			# def indices
			# 	@@indices ||= []
			# end
			
			def sort_indices
				@@sort_indices ||= []
			end
			
			def sort_by(k)
				sort_indices << k.to_sym
			end
			
			def has_sort_index?(k)
				sort_indices.include?(k.to_sym)
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