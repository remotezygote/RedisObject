require File.dirname(__FILE__) + '/spec_helper'

module DefaultSpec
	
	TestValues = {
		date: Date.today,
		number: 27,
		int: 356192,
		float: 72.362517,
		bool: true,
		# boolean: false,
		# array: [:test1,:test2],
		json: {test1: true, test2: "false"}
	}
	
	TestData = TestValues.inject({}){|acc,(k,v)| acc["a_#{k}".to_sym] = v; acc }
	
	# Delicious pizza!
	class DefaultedObject < RedisObject
		
		TestValues.keys.each do |type|
			send(type.to_sym,"a_#{type}".to_sym)
		end
		default_for :testy, "test"
		default_for :a_number, 42
		
	end
	
	describe Seabright::DefaultValues do
		before do
			RedisObject.store.flushdb
		end
		
		it "returns default value" do
			
			obj = DefaultedObject.create(TestData)
			
			obj.testy.should eq("test")
			obj.get(:a_number).should eq(27)
			obj.unset(:a_number)
			obj.get(:a_number).should eq(42)
			
		end
				
		it "returns default value after unset" do
			
			obj = DefaultedObject.create(TestData)
			
			obj.get(:a_number).should eq(27)
			obj.unset(:a_number)
			obj.get(:a_number).should eq(42)
			
		end
				
	end
end
