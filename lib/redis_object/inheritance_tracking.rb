module Seabright
	
	def RedisObject.constant_lookups
		@constant_lookups ||= {}
	end
	
	module InheritanceTracking
		
		module ClassMethods
			
			def inherited(child_class)
				RedisObject.constant_lookups[child_class.name.to_s.split("::").last.to_sym] ||= child_class
				child_classes_set.add(child_class)
			end

			def child_classes_set
				@child_classes_set ||= Set.new
			end

			def child_classes
				child_classes_set.to_a
			end
		end

		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end