require File.dirname(__FILE__) + '/spec_helper'

module ObjectTests
	class User < RedisObject
		
	end
	class Thingy < RedisObject
		
	end
	class Doodad < RedisObject
		
	end
end

describe RedisObject do
	
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
