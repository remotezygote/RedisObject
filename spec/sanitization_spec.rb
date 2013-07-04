require File.dirname(__FILE__) + '/spec_helper'

require 'redis_object/ext/sanitization'

module TriggerSpec
	
	class SensitiveObject < RedisObject
		
		include Seabright::Sanitization
		
		date :test
		bool :yay
		json :stuff
		
		named_sanitization :burn, :test, :yay
	end
	
	describe Seabright::Triggers do
		before do
			RedisObject.store.flushdb
			@secret = SensitiveObject.create(test: Time.now, yay: true, stuff: {test: "1"}, worthless: "yup", sup: "dawg")
		end
		
		it "can sanitize a field or two willy nilly" do
			
			@secret.stuff.should be_a(Hash)
			@secret.sanitize! :stuff, :sup
			@secret.stuff.should eq(nil)
			
		end
		
		it "can sanitize by name" do
			
			@secret.test.should_not eq(nil)
			@secret.yay.should eq(true)
			@secret.sanitize_by_name! :burn
			@secret.test.should eq(nil)
			@secret.yay.should eq(false)
			
		end
		
	end
end
