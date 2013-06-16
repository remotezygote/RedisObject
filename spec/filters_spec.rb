require File.dirname(__FILE__) + '/spec_helper'

module FilterSpec
	
	class FilteredObject < RedisObject
		
		def double(k,v)
			(k == :testy) && v ? [:testy,v*2] : [k,v]
		end
		set_filter :double
		
	end
	
	describe Seabright::Filters do
		before do
			RedisObject.store.flushdb
		end
		
		it "modifies set and gets correctly" do
			
			obj = FilteredObject.create("test")
			
			obj.set(:testy,"test")
			obj.get(:testy).should eq("testtest")
			
		end
		
	end
end
