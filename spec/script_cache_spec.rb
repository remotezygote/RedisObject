require File.dirname(__FILE__) + '/spec_helper'

module ScriptCacheSpec
	
	class GenericObject < RedisObject;end
	
	describe Seabright::CachedScripts do
		before do
			
			RedisObject.store.flushdb
			
			(1..5).each do |n|
				GenericObject.create(n.to_s)
			end
			
		end
		
		it "should cache scripts" do
			
			GenericObject.recently_created.first.id.should eq("5")
			
		end
		
		it "should untrack a script" do
			
			GenericObject.recently_created.first.id.should eq("5")
			GenericObject.indexed(:created_at,-1,false).to_a.last.id.should eq("4")
			
			cnt = $ScriptSHAMap.keys.count
			RedisObject.untrack_script :RevScript
			$ScriptSHAMap.keys.count.should eq(cnt-1)
			
		end
		
		it "should handle a missing script SHA" do
			
			GenericObject.recently_created.first.id.should eq("5")
			RedisObject.store.script :flush
			GenericObject.recently_created.to_a[2].id.should eq("3")
			
		end
		
		it "should expire scripts" do
			
			# $ScriptSHAMap.keys.count.should eq(1)
			
			RedisObject.stores.each do |(name,store)|
				RedisObject.expire_all_script_shas(store)
			end
			
			$ScriptSHAMap.keys.count.should eq(0)
			
		end
		
		it "should error on unknown script source" do
			
			expect { GenericObject.run_script(:MysteriousCommand) }.to raise_error
			
		end
		
	end
end
