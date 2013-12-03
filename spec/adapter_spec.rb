require File.dirname(__FILE__) + '/spec_helper'

module ObjectTests
	class User < RedisObject
		use_store :global
	end
	class Thingy < RedisObject
		
	end
	class Doodad < RedisObject
		
	end
end

describe RedisObject do
	
	it "can reconnect to redis" do
		RedisObject.reconnect!
		RedisObject.store.reconnect!
	end
	
	it "can dump to a file" do
		obj = ObjectTests::User.create("test")
		RedisObject.dump_stores_to_files("/tmp")
		SpecHelper.flushdb
	end
	
	it "can restore from a file" do
		RedisObject.restore_stores_from_files("/tmp")
		ObjectTests::User.find("test").should be_a(ObjectTests::User)
	end
	
	it "can get all stores" do
		RedisObject.stores.count.should eq(1)
	end
	
	it "can reset stores" do
		RedisObject.stores.each do |(name,store)|
			store.reset
		end
	end
	
end
