module Seabright
	module RedisObjectCleaner
		def self.clean!
			RedisObject.store.keys("*:collections").each do |key|
				if obj = RedisObject.find_by_key(key.gsub(/:collections$/,''))
					obj.collections.each do |nm,col|
						puts "Cleaning: #{nm} #{col.class} #{col.inspect}" if DEBUG
						col.cleanup!
					end
				end
			end
		end
	end
end