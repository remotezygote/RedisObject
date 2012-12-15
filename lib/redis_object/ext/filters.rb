module Seabright
	module Filters
		
		def filtered(method,*args)
			if filters = self.class.filters_for(method)
				filters.each do |f|
					args = send(f,*args)
				end
			end
			method(*args)
		end
		
		module ClassMethods
			
			def set_filter(filter)
				filter_method(:set,filter)
			end
			
			def get_filter(filter)
				filter_method(:get,filter)
			end
			
			def filter_method(method, filter)
				unless method_filters[method.to_sym]
					method_filters[method.to_sym] ||= []
					filter!(method.to_sym)
				end
				method_filters[method.to_sym] << filter.to_sym unless method_filters[method.to_sym].include?(filter.to_sym)
			end
			
			def filter!(method)
				self.class.instance_exec("")
			end
			
			def method_filters
				@method_filters ||= {}
			end
			
			def filters_for(method)
				method_filters[method.to_sym]
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end