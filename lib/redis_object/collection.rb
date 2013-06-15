module Seabright
	
	module Collections
		
		# def dump
		# 	require "utf8_utils"
		# 	out = ["puts \"Creating: #{id}\""]
		# 	s_id = id.gsub(/\W/,"_")
		# 	out << "a#{s_id} = #{self.class.cname}.new(#{actual.to_s.tidy_bytes})"
		# 	collections.each do |col|
		# 		col.each do |sobj|
		# 			out << sobj.dump
		# 		end
		# 	end
		# 	out << "a#{s_id}.save"
		# 	out.join("\n")
		# end
		
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
		
		def mset(dat)
			dat.select! {|k,v| !collections[k.to_s] }
			super(dat)
		end
		
		def set(k,v)
			@data ? super(k,v) : has_collection?(k) ? get_collection(k.to_s).replace(v) : super(k,v)
			v
		end
		
		module ClassMethods
			
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
			
			# def ref_key(ident = nil)
			# 	"#{hkey(ident)}:backreferences"
			# end
			# 
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
			
			# def referenced_by(obj)
			# 	store.sadd(ref_key,obj.hkey)
			# end
			# 
			# def backreferences(cls = nil)
			# 	out = store.smembers(ref_key).map do |backreference_hkey|
			# 		obj = RedisObject.find_by_key(backreference_hkey)
			# 		if cls && !obj.is_a?(cls)
			# 			nil
			# 		else
			# 			obj
			# 		end
			# 	end
			# 	out.compact
			# end
			# 
			# def dereference_from(obj)
			# 	obj.get_collection(collection_name).delete(hkey)
			# end
			# 
			# def dereference_from_backreferences
			# 	backreferences.each do |backreference|
			# 		dereference_from(backreference)
			# 	end
			# end
			# 
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
			out = Enumerator.new do |y|
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
			keys = run_script(reverse ? :RevScript : :FwdScript, [temp_key, index_key(idx), key, num])
			Enumerator.new do |y|
				keys.each do |member|
					y << member
				end
			end
		end
		
		def index_key(idx)
			class_const.index_key(idx)
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
		
		def match(pkt)
			Enumerator.new do |y|
				each do |i|
					if pkt.map {|hk,va| i.get(hk)==va }.all?
						y << i
					end
				end
			end
		end
		
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
					puts "Deleting #{key} because not #{a.inspect}" if DEBUG
					delete at(key)
				end
			end
			if size < 1
				puts "Deleting collection #{@name} because empty" if DEBUG
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
