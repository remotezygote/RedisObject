module Seabright
	module InheritanceTracking
		
		module ClassMethods
			def inherited(child_class)
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