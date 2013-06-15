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
		RedisObject.store.flushdb
	end
	
	it "can restore from a file" do
		RedisObject.restore_stores_from_files("/tmp")
		ObjectTests::User.find("test").should be_a(ObjectTests::User)
	end
	
	it "can be created" do
		obj = ObjectTests::User.new
	end
	
	it "can be created with an id" do
		obj = ObjectTests::User.new("test")
		obj.save
	end
	
	it "should be found by id" do
		obj = ObjectTests::User.find("test")
		obj.should_not be_nil
	end
	
	it "should save stuff" do
		obj = ObjectTests::User.find("test")
		obj.stuff = "yay!"
		obj.stuff.should == "yay!"
	end
	
	it "should retrieve stuff" do
		obj = ObjectTests::User.find("test")
		obj.stuff.should == "yay!"
	end
	
	it "can collect other objects" do
		obj = ObjectTests::User.find("test")
		obj2 = ObjectTests::Thingy.new("yay")
		obj << obj2
		obj.should have_collection(:thingies)
	end
	
	it "can reference other objects" do
		obj = ObjectTests::User.find("test")
		obj3 = ObjectTests::Doodad.new("woo")
		obj.reference obj3
		obj.should have_collection(:doodads)
	end
	
	it "should be deletable" do
		obj = ObjectTests::User.find("test")
		obj.delete!
		ObjectTests::User.find("test").should be_nil
	end
	
end
