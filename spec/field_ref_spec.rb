require File.dirname(__FILE__) + '/spec_helper'

module FieldRefSpec
	
	class Dad < RedisObject; end
	class Son < RedisObject; end
	
	describe RedisObject do
		
		before do
			RedisObject.store.flushdb
			@dad = Dad.create("daddy")
			@son = Son.create("sonny")
			@dad.stepson = @son
		end
		
		it "can store an object at  any field location" do
			
			@dad.stepson = @son
			
		end
		
		it "can get the object back by get" do
			
			@dad.get(:stepson).should be_a(Son)
			
		end
		
		it "can get the object back by bracket" do
			
			@dad[:stepson].should be_a(Son)
			
		end
		
		it "can get the object back by pseudo-getter" do
			
			@dad.stepson.should be_a(Son)
			
		end
		
		it "can get the object back after reload" do
			
			Dad.find(@dad.id).stepson.should be_a(Son)
			
		end
		
	end
end
