require File.dirname(__FILE__) + '/spec_helper'

module ViewSpec
	
	TestValues = {
		date: Date.today,
		number: 27,
		int: 356192,
		float: 72.362517,
		bool: true
	}
	
	TestData = TestValues.inject({}){|acc,(k,v)| acc["a_#{k}".to_sym] = v; acc }
	
	class ViewedObject < RedisObject
		
		named_view :aggregated, :a_float, :a_bool, :aggregate
		
		TestValues.keys.each do |type|
			send(type.to_sym,"a_#{type}".to_sym)
		end
		
		def aggregate
			a_number + a_int
		end
		
	end
	
	describe Seabright::ViewCaching do
		
		before do
			RedisObject.store.flushdb
			@obj = ViewedObject.create(TestData)
		end
		
		it "generates view" do
			
			@obj.view_as_hash(:aggregated).should be_a(Hash)
			@obj.view_as_json(:aggregated).should be_a(String)
			
		end
		
		it "views methods properly" do
			
			@obj.view_as_hash(:aggregated)["aggregate"].should eq(TestData[:a_number] + TestData[:a_int])
			
		end
		
	end
end
