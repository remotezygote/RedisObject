require File.dirname(__FILE__) + '/spec_helper'

module ObjectTests
	class User < RedisObject
		use_store :global
	end
	class Thingy < RedisObject
		
	end
	class Doodad < RedisObject
		
	end
	class Collidor < RedisObject
		def new_id
			"totsunique"
		end
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
	
	it "should be found by complex matchers" do
		obj = ObjectTests::User.find(user_id: "test")
		obj.first.should_not be_nil
		obj = ObjectTests::User.find(user_id: /test/)
		obj.first.should_not be_nil
		obj = ObjectTests::User.find(user_id: /Test/i)
		obj.first.should_not be_nil
		obj = ObjectTests::User.find(user_id: /Test/)
		obj.first.should be_nil
		obj = ObjectTests::User.find(user_id: /Test/i, blah: nil)
		obj.first.should_not be_nil
		obj = ObjectTests::User.find(user_id: /Test/, blah: nil)
		obj.first.should be_nil
	end

	it "should be found by or matchers" do
		obj = ObjectTests::User.new("sico")
		obj.save
		obj.foo = "bar!"
		obj2 = ObjectTests::User.new("notsico")
		obj2.save
		obj2.stuff = "woo!"
		res = ObjectTests::User.or_find(stuff: "woo!", foo: "bar!")
		res.count.should eq(2)
	end

	it "should be found by complex or matchers" do
		obj = ObjectTests::User.new("sico")
		obj.save
		obj.foo = "bar!"
		obj2 = ObjectTests::User.new("notsico")
		obj2.save
		obj2.stuff = "woo!"
		res = ObjectTests::User.or_find(stuff: /Woo!/i, foo: "bar!")
		res.count.should eq(2)
		res = ObjectTests::User.or_find(stuff: /Woo!/i, foo: /bar!/i)
		res.count.should eq(2)
		res = ObjectTests::User.or_find(stuff: /Woo(.*)/i, foo: /bar!/i)
		res.count.should eq(2)
		res = ObjectTests::User.or_find(stuff: /woo!/i, foo: /Bar!/)
		res.count.should eq(1)
	end
	
	it "should be found by nil matchers" do
		obj = ObjectTests::User.find(blah: nil)
		obj.first.should_not be_nil
	end
	
	it "should be found/not-found by nil composite matchers" do
		obj = ObjectTests::User.find(blah: nil, user_id: "test")
		obj.first.should_not be_nil
		obj = ObjectTests::User.find(blah: nil, user_id: "blah")
		obj.first.should be_nil
	end
	
	it "should be found by regex matchers that do not exist as keys" do
		obj = ObjectTests::User.find(blah: /test/)
		obj.first.should be_nil
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
	
	it "detects id collisions" do
		ObjectTests::Collidor.create
		ObjectTests::Collidor.create
	end
	
end
