module Seabright
	module Shardable
		
		# Intention is to override any methods needed so that the underlying data can be safely sharded
		
		module ClassMethods
			
			# same here
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
	RedisObject.send(:include,Shardable)
end
