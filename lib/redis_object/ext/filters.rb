module Seabright
	module Filters
		
		module ClassMethods
			
			def intercept_for_filters!
				return if @intercept_for_filters
				self.class_eval do
					
					filter_gets do |obj, k, v|
						if filters = self.class.filters_for(:get)
							filters.each do |f|
								out = obj.send(f,v)
							end
						end
						out
					end
					
					filter_sets do |obj, k, v|
						if filters = self.class.filters_for(:set)
							filters.each do |f|
								args = obj.send(f,k,v)
							end
						end
						unless args.is_a?(Array)
							args = [nil,nil]
						end
						args
					end
					
					# filter_msets do |dat|
					# 	if filters = self.class.filters_for(method)
					# 		filters.each do |f|
					# 			next unless args.is_a?(Array) and !args[0].nil?
					# 			args = send(f,*args)
					# 		end
					# 	end
					# 	unless args.is_a?(Array)
					# 		args = [nil,nil]
					# 	end
					# 	args
					# end
					# 
				end
				@intercept_for_filters = true
			end
			
			def set_filter(filter)
				filter_method(:set,filter)
			end
			
			def get_filter(filter)
				filter_method(:get,filter)
			end
			
			def filter_method(method, filter)
				method_filters[method.to_sym] ||= []
				method_filters[method.to_sym] << filter.to_sym unless method_filters[method.to_sym].include?(filter.to_sym)
				intercept_for_filters!
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