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
	
	it "can be created" do
		obj = ObjectTests::User.new
	end
	
	it "can be created with an id" do
		obj = ObjectTests::User.new("test")
		obj.save
	end
	
	it "can create an id" do
		obj = ObjectTests::User.new("test")
		obj.new_id
	end
	
	it "can reserve an id" do
		obj = ObjectTests::User.new("test")
		obj.reserve("test")
	end
	
	it "should be found by id" do
		obj = ObjectTests::User.find("test")
		obj.should_not be_nil
	end
	
	it "can recollect objects" do
		ObjectTests::User.recollect!
	end
	
	it "get get the first object (random)" do
		obj = ObjectTests::User.first
		obj.should be_a(ObjectTests::User)
	end
	
	it "should save stuff" do
		obj = ObjectTests::User.find("test")
		obj.stuff = "yay!"
		obj[:stuff].should eq("yay!")
		obj[:stuff] = "yayyay!"
		obj.stuff.should eq("yayyay!")
		obj.stuff = "yay!"
		obj.stuff.should eq("yay!")
	end
	
	it "should retrieve stuff" do
		obj = ObjectTests::User.find("test")
		obj.stuff.should eq("yay!")
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
	
	it "can convert raw to json" do
		obj = ObjectTests::User.find("test")
		obj.to_json.length.should > 0
	end
	
	it "should be deletable" do
		obj = ObjectTests::User.find("test")
		obj.delete!
		ObjectTests::User.find("test").should be_nil
	end
	
	it "can dump itself raw-ly" do
		obj = ObjectTests::User.create("testy")
		obj.test = true
		obj.raw.should be_a(Hash)
	end
	
	it "can iterate through instances with each" do
		ObjectTests::User.each do |obj|
			obj.should be_a(ObjectTests::User)
		end
	end
	
end
