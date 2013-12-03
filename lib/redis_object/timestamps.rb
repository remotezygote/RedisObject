module Seabright
	module Timestamps
		
		def update_timestamps
			# return unless self.class.time_matters?
			if !is_set?(:created_at)
				set(:created_at, Time.now)
			end
			set(:updated_at, Time.now)
		end
		
		module ClassMethods
			
			def intercept_sets_for_timestamps!
				return if @intercepted_sets_for_timestamps
				self.class_eval do
					alias_method :untimestamped_set, :set unless method_defined?(:untimestamped_set)
					def set(k,v)
						ret = untimestamped_set(k,v)
						set(:updated_at, Time.now) unless k.to_sym == :updated_at
						ret
					end
					alias_method :untimestamped_mset, :mset unless method_defined?(:untimestamped_mset)
					def mset(dat)
						ret = untimestamped_mset(dat)
						set(:updated_at, Time.now)
						ret
					end
					alias_method :untimestamped_setnx, :setnx unless method_defined?(:untimestamped_setnx)
					def setnx(k,v)
						ret = untimestamped_setnx(k,v)
						set(:updated_at, Time.now) unless k.to_sym == :updated_at
						ret
					end
					alias_method :untimestamped_save, :save unless method_defined?(:untimestamped_save)
					def save
						ret = untimestamped_save()
						update_timestamps
						ret
					end
				end
				@intercepted_sets_for_timestamps = true
			end
			
			# def time_matters?
			# 	@time_irrelevant != true
			# end
			# 
			# def time_matters_not!
			# 	@time_irrelevant = true
			# 	sort_indices.delete(:created_at)
			# 	sort_indices.delete(:updated_at)
			# end
			# 
			def recently_created(num=5)
				self.indexed(:created_at,num,true)
			end
			
			def recently_updated(num=5)
				self.indexed(:updated_at,num,true)
			end
			
		end
		
		def self.included(base)
			# @time_irrelevant = false
			base.send(:sort_by,:created_at)
			base.send(:sort_by,:updated_at)
			base.send(:register_format,:created_at, :date)
			base.send(:register_format,:updated_at, :date)
			base.extend(ClassMethods)
			base.intercept_sets_for_timestamps!
		end
		
	end
end