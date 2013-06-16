require File.dirname(__FILE__) + '/spec_helper'

module BenchmarkSpec
	
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
	
	class BenchmarkedObject < RedisObject
		
		TestValues.keys.each do |type|
			send(type.to_sym,"a_#{type}".to_sym)
		end
		
		def aggregate
			sleep 1.5
			42.7
		end
		benchmark :aggregate
		
	end
	
	describe Seabright::Benchmark do
		before do
			RedisObject.store.flushdb
		end
		
		it "benchmarks a call" do
			
			obj = BenchmarkedObject.create(TestData)
			
			obj.aggregate.should eq(42.7)
			
		end
						
	end
end
