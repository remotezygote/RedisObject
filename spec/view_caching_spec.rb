require File.dirname(__FILE__) + '/spec_helper'

module ViewCachingSpec
	
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
	
	class TypedObject < RedisObject
		
		named_view :aggregated, :a_float, :a_bool, :aggregate
		cache_view :aggregated
		
		TestValues.keys.each do |type|
			send(type.to_sym,"a_#{type}".to_sym)
		end
		
		def aggregate
			a_number + a_int
		end
		
	end
	
	class Container < RedisObject
		
		invalidate_downstream :TypedObject
		
	end
	
	class Baby < RedisObject
		
		invalidate_upstream :TypedObject
		
	end
	
	describe Seabright::ViewCaching do
		
		before do
			RedisObject.store.flushdb
			@obj = TypedObject.create(TestData)
			@dad = Container.create("daddy")
			@dad << @obj
			@baby = Baby.create("mama")
			@obj << @baby
		end
	
		it "generates view" do
			
			@obj.view_as_hash(:aggregated).should be_a(Hash)
			@obj.view_as_json(:aggregated).should be_a(String)
			
		end
				
		it "gets cached view on second access" do
			
			@obj.view_as_hash(:aggregated).should be_a(Hash)
			@obj.view_as_json(:aggregated).should be_a(String)
			@obj.view_is_cached?(:aggregated).should eq(true)
			@obj.view_as_hash(:aggregated).should be_a(Hash)
			@obj.view_as_json(:aggregated).should be_a(String)
						
		end
				
		it "caches are invalidated" do
			
			@obj.view_as_hash(:aggregated).should be_a(Hash)
			
			@obj.view_is_cached?(:aggregated).should eq(true)
			
			@obj.invalidate_cached_views!
			
			@obj.view_is_cached?(:aggregated).should eq(false)
			
			@obj.view_as_hash(:aggregated).should be_a(Hash)
			
			@obj.view_is_cached?(:aggregated).should eq(true)
			
			@obj.set(:demolisher, "smash")
			# 
			# @obj.view_is_cached?(:aggregated).should eq(false)
			
			
		end
				
		it "invalidates up/down stream" do
			
			@obj.view_as_hash(:aggregated).should be_a(Hash)
			
			@obj.view_is_cached?(:aggregated).should eq(true)
			
			@baby.set(:demolisher, "smash")
			
			# sleep 1
			# 
			# TypedObject.find(@obj.id).view_is_cached?(:aggregated).should eq(false)
			
			@obj.view_as_hash(:aggregated).should be_a(Hash)
			
			@obj.view_is_cached?(:aggregated).should eq(true)
			
			@dad.set(:demolisher, "smash")
			
			# sleep 1
			# 
			# TypedObject.find(@obj.id).view_is_cached?(:aggregated).should eq(false)
			
		end
				
	end
end
