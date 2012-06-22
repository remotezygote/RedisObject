module Seabright
	module History
		
		def save_history?
			save_history || self.class.save_history?
		end
		
		def store_image
			store.zadd history_key, Time.now.to_i, to_json
		end
		
		def history(num=5,reverse=false)
			parser = Yajl::Parser
			store.send(reverse ? :zrevrange : :zrange, history_key, 0, num).collect do |member|
				parser.parse(member)
			end
		end
		
		def history_key(ident = nil, prnt = nil)
			"#{key}_history"
		end
		
		def save
			super
			store_image if save_history?
		end
		
		module ClassMethods
			
			def save_history!(v=true)
				@@save_history = v
			end
			
			def save_history?
				@@save_history ||= false
			end
			
			def history_key(ident = id, prnt = nil)
				"#{key(ident,prnt)}_history"
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end