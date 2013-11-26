module Seabright
	
	module Collections
		
		def hkey_col(ident = nil)
			"#{hkey}:collections"
		end
		
		def load(o_id)
			super(o_id)
			store.smembers(hkey_col).each do |name|
				collections[name] = Seabright::Collection.load(name,self)
				define_access(name) do
					get_collection(name)
				end
				define_access(name.to_s.singularize) do
					get_collection(name).latest
				end
			end
			true
		end
		
		def delete_child(obj)
			if col = get_collection(obj.collection_name)
				col.delete obj
			end
		end
		
		def collection_name
			self.class.collection_name
		end
		
		def ref_key(ident = nil)
			"#{hkey}:backreferences"
		end
		
		def reference(obj)
			raise "Not an object." unless obj.is_a?(RedisObject)
			get_collection(obj.collection_name) << obj.hkey
			obj.referenced_by self
		end
		
		def <<(obj)
			reference obj
		end
		
		def push(obj)
			reference obj
		end
		
		def remove_collection!(name)
			store.srem hkey_col, name
		end
		
		def referenced_by(obj)
			store.sadd(ref_key,obj.hkey)
		end

		def backreferences(cls = nil)
			out = store.smembers(ref_key).map do |backreference_hkey|
				obj = RedisObject.find_by_key(backreference_hkey)
				if cls && !obj.is_a?(cls)
					nil
				else
					obj
				end
			end
			out.compact
		end

		def dereference_from(obj)
			obj.get_collection(collection_name).delete(hkey)
		end

		def dereference_from_backreferences
			backreferences.each do |backreference|
				dereference_from(backreference)
			end
		end
		
		def get(k)
			if has_collection?(k)
				get_collection(k)
			elsif has_collection?(pk = k.to_s.pluralize)
				get_collection(pk).first
			else
				super(k)
			end
		end
		
		def has_collection?(name)
			collection_names.include?(name.to_s)
		end
		
		def get_collection(name)
			if has_collection?(name)
				collections[name.to_s] ||= Collection.load(name,self)
			else
				store.sadd hkey_col, name
				@collection_names << name.to_s
				collections[name.to_s] ||= Collection.load(name,self)
				define_access(name.to_s.pluralize) do
					get_collection(name)
				end
				define_access(name.to_s.singularize) do
					get_collection(name).latest
				end
			end
			collections[name.to_s]
		end
		
		def collections
			@collections ||= {}
		end
		
		def collection_names
			@collection_names ||= store.smembers(hkey_col)
		end
		
		def collect_type_by_key(col,*keys)
			collect = get_collection(col)
			keys.each do |k|
				collect << k
			end
		end
		
		module ClassMethods
			
			def intercept_sets_for_collecting!
				return if @intercepted_sets_for_collecting
				self.class_eval do
					
					filter_gets do |obj, k, v|
						puts "Looking for collection: #{k}"
						if obj.has_collection?(k)
							return obj.get_collection(k)
						elsif obj.has_collection?(pk = k.to_s.pluralize)
							return obj.get_collection(pk).first
						end
						puts "Not found."
						v
					end
					
					filter_sets do |obj, k, v|
						if obj.has_collection?(k)
							obj.get_collection(k.to_s).replace(v)
							return [nil,nil]
						end
						[k,v]
					end
					
					filter_msets do |obj, dat|
						dat.select {|k,v| !obj.collections[k.to_s] }
					end
					
				end
				@intercepted_sets_for_collecting = true
			end
			
			def hkey_col(ident = nil)
				"#{hkey(ident)}:collections"
			end
			
			def delete_child(obj)
				if col = get_collection(obj.collection_name)
					col.delete obj
				end
			end
			
			def collection_name
				self.name.split('::').last.pluralize.underscore.to_sym
			end
			
			def reference(obj)
				name = obj.collection_name
				store.sadd hkey_col, name
				get_collection(name) << obj.hkey
			end
			
			def <<(obj)
				reference obj
			end

			def push(obj)
				reference obj
			end
			
			def remove_collection!(name)
				store.srem hkey_col, name
			end
			
			def has_collection?(name)
				store.sismember(hkey_col,name.to_s)
			end
			
			def get_collection(name)
				collections[name.to_s] ||= Collection.load(name,self)
				collections[name.to_s]
			end
			
			def collections
				@collections ||= {}
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
			base.intercept_sets_for_collecting!
		end
		
	end
	
	class Collection < Array
		
		include Seabright::CachedScripts
		
		def initialize(name,owner)
			@name = name.to_s
			@owner = owner
		end
		
		def remove!
			@owner.remove_collection! @name
		end
		
		def latest
			indexed(:created_at,5,true).first || first
		end
		
		def indexed(idx,num=-1,reverse=false)
			keys = keys_by_index(idx,num,reverse)
			out = ListEnumerator.new(keys) do |y|
				keys.each do |member|
					if a = class_const.find_by_key(member)
						y << a
					end
				end
			end
			if block_given?
				out.each do |itm|
					yield itm
				end
			else
				out
			end
		end
		
		def temp_key
			"#{key}::zintersect_temp::#{RedisObject.new_id(4)}"
		end
		
		RedisObject::ScriptSources::FwdScript = "redis.call('ZINTERSTORE', KEYS[1], 2, KEYS[2], KEYS[3], 'WEIGHTS', 1, 0)\nlocal keys = redis.call('ZRANGE', KEYS[1], 0, KEYS[4])\nredis.call('DEL', KEYS[1])\nreturn keys".freeze
		RedisObject::ScriptSources::RevScript = "redis.call('ZINTERSTORE', KEYS[1], 2, KEYS[2], KEYS[3], 'WEIGHTS', 1, 0)\nlocal keys = redis.call('ZREVRANGE', KEYS[1], 0, KEYS[4])\nredis.call('DEL', KEYS[1])\nreturn keys".freeze
		
		def keys_by_index(idx,num=-1,reverse=false)
			keys = run_script(reverse ? :RevScript : :FwdScript, [temp_key, sort_index_key(idx), key, num])
			ListEnumerator.new(keys) do |y|
				keys.each do |member|
					y << member
				end
			end
		end
		
		def sort_index_key(idx)
			class_const.sort_index_key(idx)
		end
		
		def item_key(k)
			"#{class_const}:#{k}_h"
		end
		
		def find(k)
			if k.is_a? String
				return real_at(item_key(k))
			elsif k.is_a? Hash
				return match(k)
			elsif k.is_a? Integer
				return real_at(at(k))
			end
			return nil
		end
		
		def [](k)
			find k
		end
		
		NilPattern = 'nilpattern:'
		
		RedisObject::ScriptSources::ColMatcher = "
			local out = {}
			local val
			local pattern
			for i, v in ipairs(KEYS) do
				val = redis.call('HGET',v,ARGV[1])
				if val then
					if ARGV[2]:find('^pattern:') then
						pattern = ARGV[2]:gsub('^pattern:','')
						if val:match(pattern) then
							table.insert(out,KEYS[i])
						end
					elseif ARGV[2]:find('^ipattern:') then
						pattern = ARGV[2]:gsub('^ipattern:',''):lower()
						if val:lower():match(pattern) then
							table.insert(out,KEYS[i])
						end
					else
						if val == ARGV[2] then
							table.insert(out,KEYS[i])
						end
					end
				else
					if ARGV[2] == '#{NilPattern}' then
						table.insert(out,KEYS[i])
					end
				end
			end
			return out".gsub(/\t/,'').freeze
		
		RedisObject::ScriptSources::ColMultiMatcher = "
			local out = {}
			local matchers = {}
			local matcher = {}
			local mod
			for i=1,#ARGV do
				mod = i % 2
				if mod == 1 then
					matcher[1] = ARGV[i]
				else
					matcher[2] = ARGV[i]
					table.insert(matchers,matcher)
					matcher = {}
				end
			end
			local val
			local good
			local pattern
			for i, v in ipairs(KEYS) do
				good = true
				for n=1,#matchers do
					val = redis.call('HGET',v,matchers[n][1])
					if val then
						if matchers[n][2]:find('^pattern:') then
							pattern = matchers[n][2]:gsub('^pattern:','')
							if val:match(pattern) then
								good = good
							else
								good = false
								break
							end
						elseif matchers[n][2]:find('^ipattern:') then
							pattern = matchers[n][2]:gsub('^ipattern:',''):lower()
							if val:lower():match(pattern) then
								good = good
							else
								good = false
								break
							end
						else
							if val ~= matchers[n][2] then
								good = false
								break
							end
						end
					else
						if matchers[n][2] == '#{NilPattern}' then
							good = good
						else
							good = false
							break
						end
					end
				end
				if good == true then
					table.insert(out,KEYS[i])
				end
			end
			return out".gsub(/\t/,'').freeze

		RedisObject::ScriptSources::ColOrMatcher = "
			local out = {}
			local matchers = {}
			local matcher = {}
			local mod
			for i=1,#ARGV do
				mod = i % 2
				if mod == 1 then
					matcher[1] = ARGV[i]
				else
					matcher[2] = ARGV[i]
					table.insert(matchers,matcher)
					matcher = {}
				end
			end

			local val
			local good
			local pattern
			for i, v in ipairs(KEYS) do
				good = false
				for n=1,#matchers do
					val = redis.call('HGET',v,matchers[n][1])
					if val then
						if matchers[n][2]:find('^pattern:') then
							pattern = matchers[n][2]:gsub('^pattern:','')
							if val:match(pattern) then
								good = true
								break
							else
								good = good
							end
						elseif matchers[n][2]:find('^ipattern:') then
							pattern = matchers[n][2]:gsub('^ipattern:',''):lower()
							if val:lower():match(pattern) then
								good = true
								break
							else
								good = good
							end
						else
							if val == matchers[n][2] then
								good = true
								break
							end
						end
					else
						if matchers[n][2] == '#{NilPattern}' then
							good = good
							break
						else
							good = false
						end
					end
				end
				if good == true then
					table.insert(out,KEYS[i])
				end
			end
			return out".gsub(/\t/,'').freeze
		
		def match(pkt, use_or=false)
			if use_or
				mtchr = :ColOrMatcher
			else
				mtchr = pkt.keys.count > 1 ? :ColMultiMatcher : :ColMatcher
			end
			pkt = pkt.flatten.reduce([]) do |i,v|
				x = case v
				when Regexp
					convert_regex_to_lua(v)
				when Array
					raise ArgumentError.new("An array can only be used with the find_or method") unless use_or
					inject_key(i.last, v)
				when NilClass
					NilPattern
				else
					v.to_s
				end
				i << x
				i
			end
			kys = run_script(mtchr,self,pkt.flatten)
			ListEnumerator.new(kys) do |y|
				kys.each do |k|
					y << class_const.find_by_key(k)
				end
			end
		end

		def inject_key(key,list)
			out = []
			list.each do |i|
				if i == list.first
					out << i
				else
					out << key
					out << i
				end
			end
			out
		end
		
		def convert_regex_to_lua(reg)
			"#{reg.casefold? ? "i" : ""}pattern:#{reg.source.gsub("\\","")}"
		end
		
		# def match(pkt)
		# 	Enumerator.new do |y|
		# 		each do |i|
		# 			if pkt.all? {|hk,va| i.get(hk)==va }
		# 				y << i
		# 			end
		# 		end
		# 	end
		# end
		
		def real_at(key)
			class_const.find_by_key(key)
		end
		
		def objects
			each.to_a
		end
		
		def first
			class_const.find_by_key(super)
		end
		
		def last
			class_const.find_by_key(super)
		end
		
		def each
			out = Enumerator.new do |y|
				each_index do |key|
					if a = class_const.find_by_key(at(key))
						y << a
					end
				end
			end
			if block_given?
				out.each do |a|
					yield a
				end
			else
				out
			end
		end
		
		def cleanup!
			each_index do |key|
				unless a = class_const.find_by_key(at(key))
					Log.debug "Deleting #{key} because not #{a.inspect}"
					delete at(key)
				end
			end
			if size < 1
				Log.debug "Deleting collection #{@name} because empty"
				remove!
			end
		end
		
		def map(&block)
			each.map(&block)
		end
		
		def select(&block)
			return nil unless block_given?
			Enumerator.new do |y|
				each_index do |key|
					if (a = class_const.find_by_key(at(key))) && block.call(a)
						y << a
					end
				end
			end
		end
		
		def delete(obj)
			k = obj.class == String ? obj : obj.hkey
			store.zrem(key,k)
			super(k)
		end
		
		def clear!
			store.zrem(key,self.join(" "))
		end
		
		def <<(obj)
			k = obj.class == String ? obj : obj.hkey
			store.zadd(key,store.zcount(key,"-inf", "+inf"),k)
			super(k)
		end
		
		def push(obj)
			self << obj
		end
		
		def class_const
			self.class.class_const_for(@name)
		end
		
		def store
			class_const.store
		end
		
		def key
			"#{@owner ? "#{@owner.key}:" : ""}COLLECTION:#{@name}"
		end
		
		class << self
			
			def load(name,owner)
				out = new(name,owner)
				out.replace class_const_for(name).store.zrange(out.key,0,-1)
				out
			end
			
			def class_const_for(name)
				Object.const_get(name.to_s.classify.to_sym) rescue RedisObject
			end

		end
		
	end
	
end
