require File.dirname(__FILE__) + '/spec_helper'

module TriggerSpec
	
	class TimestampedObject < RedisObject;end
	
	class UnTimestampedObject < RedisObject
		# time_matters_not!
	end
	
	describe Seabright::Triggers do
		before do
			RedisObject.store.flushdb
		end
		
		it "should get recently created object" do
			
			(1..5).each do |n|
				TimestampedObject.create(n.to_s)
				sleep Random.rand(1.0)
			end
			
			TimestampedObject.recently_created.first.id.should eq("5")
						
		end
						
	end
end
