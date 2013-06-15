require File.dirname(__FILE__) + '/spec_helper'

module CollectionSpec
	
	class GrandDad < RedisObject; end
	class Daddy < RedisObject; end
	class Son < RedisObject; end
	class GrandSon < RedisObject; end
	
	describe Seabright::Filters do
		before do
			RedisObject.store.flushdb
			@granddad = GrandDad.create("gramps")
			@dad = Daddy.create("dad")
			@son = Son.create("son")
			@sonny = Son.create("sonny")
			@grandson = GrandSon.create("baby")
			@granddad << @dad
			@granddad << @son
			@dad << @son
			@dad << @sonny
			@son << @grandson
		end
		
		it "should have appropriate collections" do
			
			@granddad.has_collection?(:daddies).should eq(true)
			@granddad.has_collection?(:sons).should eq(true)
			@granddad.has_collection?(:grand_sons).should eq(false)
			
		end
		
		it "should be able to iterate over collected items" do
			
			@dad.sons.count.should eq(2)
			@dad.sons.each do |s|
				s.should be_a(Son)
			end
			
		end
		
		it "can find items in a collection" do
			
			# @dad.sons.find(@sonny.key).should be_a(Son)
			@dad.sons.find(son_id: "sonny").first.should be_a(Son)
			
		end
		
	end
end
