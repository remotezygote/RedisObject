module Seabright
	module Timestamps
		
		def update_timestamps
			return if @@time_irrelevant
			set(:created_at, Time.now) if !is_set?(:created_at)
			set(:updated_at, Time.now)
		end
		
		def mset(dat)
			super(dat)
			set(:updated_at, Time.now)
		end
		
		def set(k,v)
			super(k,v)
			set(:updated_at, Time.now) unless k.to_sym == :updated_at
		end
		
		def save
			super
			update_timestamps
		end
		
		module ClassMethods
			
			def time_matters_not!
				@@time_irrelevant = true
				@@sort_indices.delete(:created_at)
				@@sort_indices.delete(:updated_at)
			end
			
			def recently_created(num=5)
				self.indexed(:created_at,num,true)
			end
			
			def recently_updated(num=5)
				self.indexed(:updated_at,num,true)
			end
			
		end
		
		def self.included(base)
			@@time_irrelevant = false
			base.send(:sort_by,:created_at)
			base.send(:sort_by,:updated_at)
			base.send(:register_format,:created_at, :date)
			base.send(:register_format,:updated_at, :date)
			base.extend(ClassMethods)
		end
		
	end
end