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
	
	# Delicious pizza!
	class IndexedObject < RedisObject
		
		TestValues.keys.each do |type|
			send(type.to_sym,"a_#{type}".to_sym)
		end
		
		sort_by :a_number
		sort_by :a_bool
		
	end
	
	describe Seabright::Indices do
		before do
			RedisObject.store.flushdb
		end
		
		it "indexes on integer field" do
			
			5.times do
				obj = IndexedObject.create(a_number: Random.rand(100), a_bool: true)
			end
			
			IndexedObject.indexed(:a_number,3,true).count.should eq(3)
			IndexedObject.indexed(:a_number,3,true) do |o|
				o.should be_a(IndexedObject)
			end
			
		end
				
	end
end
