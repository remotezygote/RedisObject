require File.dirname(__FILE__) + '/spec_helper'

module TypeSpec
	
	TestValues = {
		date: Date.today,
		number: 27,
		int: 356192,
		float: 72.362517,
		bool: true,
		boolean: false,
		array: ["test1","test2"],
		json: {test1: true, test2: "false"}
	}
	
	TestData = TestValues.inject({}){|acc,(k,v)| acc["a_#{k}".to_sym] = v; acc }
	
	class TypedObject < RedisObject
		TestValues.keys.each do |type|
			send(type.to_sym,"a_#{type}".to_sym)
		end
	end
	
	class TypedChild < TypedObject; end
	
	describe Seabright::Types do
		before do
			RedisObject.store.flushdb
		end
	
		it "can be created via data packet" do
			
			obj = TypedObject.create(TestData)
			
			TestData.each do |k,v|
				obj.get(k).should eq(v)
			end
			
		end
		
		it "inherits types" do
			
			obj = TypedChild.create(TestData)
			
			TestData.each do |k,v|
				obj.get(k).should eq(v)
			end
			
		end
		
		it "can be instantiated (new) via data packet" do
			
			obj = TypedObject.new(TestData)
			
			TestData.each do |k,v|
				obj.get(k).should eq(v)
			end
			
		end
		
		it "can be created via individual sets" do
			
			obj = TypedObject.new
			
			TestData.each do |k,v|
				obj.set(k,v)
				obj.get(k).should eq(v)
			end
			
		end
		
		it "gets correct values after being found" do
			
			objc = TypedObject.create(TestData)
			obj = TypedObject.find(objc.id)
			
			TestData.each do |k,v|
				obj.get(k).should eq(v)
			end
			
		end
		
		it "nullifies non-date date value" do
			
			obj = TypedObject.new
			
			obj.a_date = "sjahfgasjfg"
			obj.a_date.should eq(nil)
			
		end
		
		it "describes itself" do
			
			obj = TypedObject.create(TestData)
			objc = TypedChild.create(TestData)
			
			desc = TypedObject.describe
			TypedObject.dump_schema(File.open("/tmp/redisobject_dump_test","w"))
			
		end
		
	end
end
