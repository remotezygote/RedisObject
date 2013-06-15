require File.dirname(__FILE__) + '/spec_helper'

module CollectionSpec
	
	class GrandDad < RedisObject; end
	class Daddy < RedisObject; end
	class Son < RedisObject; end
	class GrandSon < RedisObject; end
	
	describe Seabright::Collections do
		before do
			
			RedisObject.store.flushdb
			@granddad = GrandDad.create("gramps")
			@dad = Daddy.create("dad")
			@son = Son.create("sun")
			@sonny = Son.create("sonny")
			@grandson = GrandSon.create("baby")
			GrandDad << @dad
			@granddad << @dad
			@granddad << @son
			@dad << @son
			@dad.push @sonny
			@son.reference @grandson
			
		end
		
		it "can reference other objects" do
			
			@granddad.daddies.count.should eq(1)
			@granddad.sons.count.should eq(1)
			@dad.sons.count.should eq(2)
			
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
			
			@dad = Daddy.find("dad")
			@dad.sons.find(son_id: "sonny").first.should be_a(Son)
			
		end
		
		it "can get one collection item" do
			
			@dad = Daddy.find("dad")
			@dad.son.should be_a(Son)
			
		end
		
		it "can get one collection item" do
			
			@dad = Daddy.find("dad")
			@dad.get(:son).should be_a(Son)
			
		end
		
		it "can get backreferences of a type" do
			
			@son.backreferences(GrandDad).each do |s|
				s.should be_a(GrandDad)
			end
			
		end
		
		it "can dereference itself" do
			
			@dad.dereference_from_backreferences
			GrandDad.find("gramps").daddies.count.should eq(0)
			
		end
		
		it "can delete items from a collection" do
			
			@dad.sons.delete(@sonny)
			@dad.sons.find(son_id: "sonny").first.should be_a(NilClass)
			@dad.sons.count.should eq(1)
			
			@dad.delete_child(@son)
			@dad.get(:sons).count.should eq(0)
			
		end
		
		it "can delete a collection" do
			
			@dad.sons.remove!
			@dad.collections.keys.should_not include(:sons)
			@son.remove_collection!(:grand_sons)
			@son.collections.keys.should_not include(:grand_sons)
			
		end
		
	end
end
