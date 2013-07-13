require File.dirname(__FILE__) + '/spec_helper'

module RenameClassSpec
	# Delicious pizza!
	class Pizza < RedisObject; end
	# We love toppings but our current name Topping is too ambiguous!
	class Topping < RedisObject; end
	# Let's change the class name to PizzaTopping!
	class PizzaTopping < RedisObject; end

	describe Seabright::Storage::Redis, "#rename_class" do
		before do
			RedisObject.store.flushdb

			mozzarella = Topping.create(:mozzarella)
			basil      = Topping.create(:basil)
			tomato     = Topping.create(:tomato)
			garlic     = Topping.create(:garlic)
			oregano    = Topping.create(:oregano)
			olive_oil  = Topping.create(:olive_oil)

			marinara = Pizza.create(:marinara)
			[ tomato, garlic, oregano, olive_oil ].each{|topping| marinara << topping }

			margherita = Pizza.create(:margherita)
			[ tomato, mozzarella, basil, olive_oil ].each{|topping| margherita << topping }
		end
	
		it "setup works" do
			margherita = Pizza.find(:margherita)
			marinara = Pizza.find(:marinara)
			mozzarella = Topping.find(:mozzarella)
			basil      = Topping.find(:basil)
			tomato     = Topping.find(:tomato)
			garlic     = Topping.find(:garlic)
			oregano    = Topping.find(:oregano)
			olive_oil  = Topping.find(:olive_oil)

			[ mozzarella, basil, tomato, garlic, oregano, olive_oil ].each do |topping|
				topping.get(:class).should == Topping.name
				topping.get(:key).should == "RenameClassSpec::Topping:#{topping.id}"
				topping.get(:topping_id).should == topping.id
			end

			Topping.indexed(:created_at).first.should_not be_nil
			Topping.indexed(:created_at).count.should == 5
			
			[margherita, marinara].each do |pizza|
				pizza.pizza_toppings.should be_nil
				pizza.toppings.count.should == 4
				pizza.toppings.should include(tomato.hkey)
				pizza.toppings.should include(olive_oil.hkey)
			end

			margherita.toppings.should include(basil.hkey)
			margherita.toppings.should include(mozzarella.hkey)
			marinara.toppings.should include(oregano.hkey)
			marinara.toppings.should include(garlic.hkey)
		end

		it "renames a class" do
			RedisObject.store.rename_class(:"RenameClassSpec::Topping", :"RenameClassSpec::PizzaTopping")

			margherita = Pizza.find(:margherita)
			marinara = Pizza.find(:marinara)
			mozzarella = PizzaTopping.find(:mozzarella)
			basil      = PizzaTopping.find(:basil)
			tomato     = PizzaTopping.find(:tomato)
			garlic     = PizzaTopping.find(:garlic)
			oregano    = PizzaTopping.find(:oregano)
			olive_oil  = PizzaTopping.find(:olive_oil)

			[ mozzarella, basil, tomato, garlic, oregano, olive_oil ].each do |topping|
				topping.get(:class).should == PizzaTopping.name
				topping.get(:key).should == "RenameClassSpec::PizzaTopping:#{topping.id}"
				topping.get(:pizzatopping_id).should == topping.id
				# topping.get(:topping_id).should == nil
			end

			[margherita, marinara].each do |pizza|
				pizza.toppings.should be_nil
				pizza.pizza_toppings.count.should == 4
				pizza.pizza_toppings.should include(tomato.hkey)
				pizza.pizza_toppings.should include(olive_oil.hkey)
			end

			margherita.pizza_toppings.should include(basil.hkey)
			margherita.pizza_toppings.should include(mozzarella.hkey)
			marinara.pizza_toppings.should include(oregano.hkey)
			marinara.pizza_toppings.should include(garlic.hkey)

			PizzaTopping.indexed(:created_at).first.should_not be_nil
			PizzaTopping.indexed(:created_at).count.should == 5
		end
	end
end
