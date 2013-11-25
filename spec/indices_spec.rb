require File.dirname(__FILE__) + '/spec_helper'

module IndexSpec
	
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
	
	class SortedObject < RedisObject
		
		TestValues.keys.each do |type|
			send(type.to_sym,"a_#{type}".to_sym)
		end
		
		sort_by :a_number
		sort_by :a_bool
		
	end
	
	class IndexedObject < RedisObject
		
		index :some_text
		
	end
	
	describe Seabright::Indices do
		
		before do
			RedisObject.store.flushdb
		end
		
		it "sorts on integer field" do
			
			5.times do
				obj = SortedObject.create(a_number: Random.rand(100), a_bool: true)
			end
			
			SortedObject.indexed(:a_number,3,true).count.should eq(3)
			SortedObject.indexed(:a_number,3,true) do |o|
				o.should be_a(SortedObject)
			end
			
		end
				
		it "indexes on string field" do
			
			cnt = 0
			5.times do
				obj = IndexedObject.create(some_text: "a" + cnt.to_s)
				cnt += 1
			end
			
			IndexedObject.find_first(some_text: "a0").should be_a(IndexedObject)
			IndexedObject.find_first(some_text: "a4").should be_a(IndexedObject)
			IndexedObject.find_first(some_text: "a5").should eq(nil)
			
			IndexedObject.reindex_all_indices!
			
			IndexedObject.find_first(some_text: "a0").should be_a(IndexedObject)
			IndexedObject.find_first(some_text: "a4").should be_a(IndexedObject)
			IndexedObject.find_first(some_text: "a5").should eq(nil)
			
			RedisObject.reindex_everything!
			
			IndexedObject.find_first(some_text: "a0").should be_a(IndexedObject)
			IndexedObject.find_first(some_text: "a4").should be_a(IndexedObject)
			IndexedObject.find_first(some_text: "a5").should eq(nil)
			
			# IndexedObject.indexed(:a_number,3,true) do |o|
			# 	o.should be_a(IndexedObject)
			# end
			
		end
				
	end
end
