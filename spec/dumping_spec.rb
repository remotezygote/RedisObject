require File.dirname(__FILE__) + '/spec_helper'

module DumpingSpec
	
	class DumpableObject < RedisObject
		
		int :phone
		bool :mailed
		date :canceled_at
				
	end
	
	class GenericObject < RedisObject
		
		json :complex
		
	end
	
	describe Seabright::Triggers do
		before do
			RedisObject.store.flushdb
			5.times do
				d = DumpableObject.create(phone: Random.rand(100)*555, mailed: true, canceled_at: Time.now)
				d << GenericObject.create(complex: {woot: true, ohnoes: false})
			end
		end
		
		it "can dump an object" do
			
			r = DumpableObject.latest.to_yaml
			r.size.should > 100
			
		end
		
		it "can dump to json" do
			
			r = DumpableObject.latest.to_json
			r.size.should > 100
			
		end
		
		it "can dump errthing" do
			
			r = RedisObject.dump_everything
			r.size.should > 100
			
		end
		
	end
end
