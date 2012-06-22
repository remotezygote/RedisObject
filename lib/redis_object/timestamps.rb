module Seabright
	module Timestamps
		
		def update_timestamps
			return if @@time_irrelevant
			set(:created_at, Time.now) if !get(:created_at)
			set(:updated_at, Time.now)
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