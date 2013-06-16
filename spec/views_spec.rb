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
		
		named_view :bare, :a_float, :a_bool
		named_view :aggregated, :a_float, :a_bool, :aggregate
		named_view :aggregated_only, :method => :aggregate
		named_view :proc, {:lambda => Proc.new {|o| o.get(:a_bool) } }, :aggregate
		named_view :hashy, {:hesher => :a_number }, :aggregate
		
		TestValues.keys.each do |type|
			send(type.to_sym,"a_#{type}".to_sym)
		end
		
		def aggregate
			a_number + a_int
		end
		
	end
	
	describe Seabright::Views do
		
		before do
			RedisObject.store.flushdb
			@obj = ViewedObject.create(TestData)
		end
		
		it "generates view" do
			
			@obj.view_as_hash(:bare).should be_a(Hash)
			@obj.view_as_json(:bare).should be_a(String)
			
		end
		
		it "generates mthod-only view" do
			
			@obj.view_as_hash(:aggregated_only).should be_a(Fixnum)
			
		end
		
		it "views methods properly" do
			
			@obj.view_as_hash(:aggregated)["aggregate"].should eq(TestData[:a_number] + TestData[:a_int])
			
		end
		
		it "executes procs within view" do
			
			@obj.view_as_hash(:proc).should be_a(Hash)
			
		end
		
		it "generates hashes within view" do
			
			@obj.view_as_hash(:hashy).should be_a(Hash)
			
		end
		
	end
end
