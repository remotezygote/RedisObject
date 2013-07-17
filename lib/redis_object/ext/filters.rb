module Seabright
	module Filters
		
		module ClassMethods
			
			def intercept_for_filters!
				return if @intercept_for_filters
				self.class_eval do
					
					def filtered_method_call(method,*args)
						if filters = self.class.filters_for(method)
							filters.each do |f|
								args = send(f,*args)
							end
						end
						unless args.is_a?(Array)
							args = [nil,nil]
						end
						send("unfiltered_#{method.to_s}".to_sym,*args)
					end
					
					alias_method :unfiltered_get, :get unless method_defined?(:unfiltered_get)
					def get(k)
						filtered_method_call(:get,k)
					end
					
					alias_method :unfiltered_set, :set unless method_defined?(:unfiltered_set)
					def set(k,v)
						filtered_method_call(:set,k,v)
					end
					
					alias_method :unfiltered_setnx, :setnx unless method_defined?(:unfiltered_setnx)
					def setnx(k,v)
						filtered_method_call(:setnx,k,v)
					end
					
				end
				@intercept_for_filters = true
			end
			
			def set_filter(filter)
				filter_method(:set,filter)
				filter_method(:setnx,filter)
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