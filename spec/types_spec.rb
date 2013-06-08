require File.dirname(__FILE__) + '/spec_helper'

module TypeSpec
	
	TestValues = {
		date: Date.today,
		number: 27,
		int: 356192,
		float: 72.362517,
		bool: true,
		boolean: false,
		# array: [:test1,:test2],
		# json: {test1: true, test2: "false"}
	}
	
	TestData = TestValues.inject({}){|acc,(k,v)| acc["a_#{k}".to_sym] = v; acc }
	
	# Delicious pizza!
	class TypedObject < RedisObject
		TestValues.keys.each do |type|
			puts "Setting up: send(#{type.to_sym},\"a_#{type}\".to_sym)"
			send(type.to_sym,"a_#{type}".to_sym)
			puts field_formats.inspect
		end
	end
	
	puts TypedObject.describe
	
	describe Seabright::Types do
		before do
			RedisObject.store.flushdb
		end
	
		it "can be created via data packet" do
			
			obj = TypedObject.create(TestData)
			
			TestData.each do |k,v|
				obj.get(k).should satisfy{|n|
					puts "#{n.class} is_a? #{v.class}"
					n.is_a?(v.class)
				}
				obj.get(k).should == v
			end
			
		end
		
		it "can be instantiated (new) via data packet" do
			
			obj = TypedObject.new(TestData)
			
			TestData.each do |k,v|
				obj.get(k).should satisfy{|n|
					n.is_a?(v.class)
				}
				obj.get(k).should == v
			end
			
		end
		
		it "can be created instantiated via individual sets" do
			
			obj = TypedObject.new
			
			TestValues.each do |k,v|
				obj.set(k,v)
				obj.get(k).should satisfy{|n|
					n.is_a?(v.class)
				}
				obj.get(k).should == v
			end
			
		end
		
	end
end
