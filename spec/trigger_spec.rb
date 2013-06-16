require File.dirname(__FILE__) + '/spec_helper'

module TriggerSpec
	
	class TriggeredObject < RedisObject
		
		int :raw_phone
		bool :mailed_flag
		bool :mail_was_sent_for_realz
		date :srsly_updated
		
		def track_phone_raw(k,v)
			set(:raw_phone, v.gsub(/[^0-9]/,'').to_i)
		end
		
		trigger_on_set :phone, :track_phone_raw
		
		def sent_mail(k,v)
			set(:mail_was_sent_for_realz, true)
		end
		
		def updated_redundant(k,v)
			set(:srsly_updated, Time.now)
		end
		
		trigger_on_set :mailed_flag, :sent_mail
		trigger_on_update :updated_redundant
		
	end
	
	describe Seabright::Triggers do
		before do
			RedisObject.store.flushdb
		end
		
		it "triggers on a call" do
			
			obj = TriggeredObject.create("trig")
			
			obj.phone = "(970) 555-1212"
			obj.raw_phone.should eq(9705551212)
			success = obj.setnx(:mailed_flag,true)
			success.should eq(true)
			obj.mail_was_sent_for_realz.should eq(true)
			success = obj.setnx(:mailed_flag,true)
			success.should eq(false)
			
		end
						
	end
end
