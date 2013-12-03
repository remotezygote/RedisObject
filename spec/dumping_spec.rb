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
	
	describe Seabright::Dumping do
		before do
			SpecHelper.flushdb
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
			
			r = RedisObject.dump_everything(:yml)
			r.size.should > 100
			# r = RedisObject.dump_everything(:json)
			# r.size.should > 100
			
		end
		
		it "can dump a single class" do
			
			r = RedisObject.dump_everything(:yml)
			r.size.should > 100
			d = DumpableObject.dump_all(:yml)
			d.size.should > 100
			d.size.should < r.size
			# r = RedisObject.dump_everything(:json)
			# r.size.should > 100
			
		end
		
		it "can load back in a dump" do
			
			r = RedisObject.dump_everything(:yml)
			r.size.should > 100
			SpecHelper.flushdb
			RedisObject.load_dump r, :yml
			DumpableObject.latest.generic_objects.count.should eq(1)
			
			# r = RedisObject.dump_everything(:json)
			# r.size.should > 100
			# SpecHelper.flushdb
			# RedisObject.load_dump r, :json
			# DumpableObject.latest.generic_objects.count.should eq(1)
			
		end
		
	end
end
