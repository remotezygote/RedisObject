module Seabright
	
	module Collections
		
		def dump
			require "utf8_utils"
			out = ["puts \"Creating: #{id}\""]
			s_id = id.gsub(/\W/,"_")
			out << "a#{s_id} = #{self.class.cname}.new(#{actual.to_s.tidy_bytes})"
			collections.each do |col|
				col.each do |sobj|
					out << sobj.dump(self)
				end
			end
			out << "a#{s_id}.save"
			out.join("\n")
		end
		
		def hkey_col(ident = nil)
			"#{hkey}:collections"
		end
		
		def load(o_id)
			super(o_id)
			store.smembers(hkey_col).each do |name|
				collections[name] = Seabright::Collection.load(name,self)
			end
			true
		end
		
		def save
			super
			collections.each do |k,col|
				col.save
			end
		end
		
		def delete_child(obj)
			if col = collections[obj.collection_name]
				col.delete obj.hkey
			end
		end
		
		def collection_name
			self.class.plname.underscore.to_sym
		end
		
		def ref_key(ident = nil)
			"#{hkey}:backreferences"
		end
		
		def reference(obj)
			name = obj.collection_name
			store.sadd hkey_col, name
			collections[name.to_s] ||= Seabright::Collection.load(name,self)
			collections[name.to_s] << obj.hkey
			obj.referenced_by self
		end
		alias_method :<<, :reference
		alias_method :push, :reference
		
		def referenced_by(obj)
			store.sadd(ref_key,obj.hkey)
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
			store.sismember(hkey_col,name.to_s)
		end
		
		def get_collection(name)
			collections[name.to_s] ||= Collection.load(name,self)
			collections[name.to_s]
		end
		
		def collections
			@collections ||= {}
		end
		
		def set(k,v)
			@data ? super(k,v) : collections[k.to_s] ? get_collection(k.to_s).replace(v) : super(k,v)
			v
		end
		
		module ClassMethods
			
			def hkey_col(ident = id)
				"#{hkey(ident)}:collections"
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
	
	
	class Collection < Array
		
		def initialize(name,parent)
			@name = name.to_s
			@parent = parent
		end
		
		def indexed(idx,num=5,reverse=false,&block)
			return indexed_yield(idx,num,reverse,&block) if block
			out = []
			indexed_yield(idx,num,reverse) do |member|
				out << member
			end
			out
		end
		
		def indexed_yield(idx,num=5,reverse=false,&block)
			raise "No block specified" unless block
			keys_by_index(idx,num,reverse) do |member|
				if a = RedisObject.find_by_key(member)
					yield a
				end
			end
			nil
		end
		
		def temp_key
			"zintersect_temp"
		end
		
		def keys_by_index(idx,num=5,reverse=false,&block)
			keys = nil
			store.multi do
				store.zinterstore(temp_key, [index_key(idx), key], {:weights => ["1","0"]})
				keys = store.send(reverse ? :zrevrange : :zrange, temp_key, 0, num)
				store.del temp_key
			end
			keys.value.each do |member|
				yield member
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
				return real_at item_key(k)
			elsif k.is_a? Hash
				each do |i|
					return i if k.map {|hk,va| i.get(hk)==va }.all?
				end
			end
			return nil
		end
		alias_method :[], :find
		
		def match(pkt)
			each do |i|
				yield i if pkt.map {|hk,va| i.get(hk)==va }.all?
			end
		end
		
		def real_at(key)
			RedisObject.find_by_key(key)
		end
		
		# def [](idx)
		# 	class_const.find_by_key(at(idx))
		# end
		
		def objects
			out = []
			each_index do |key|
				a = RedisObject.find_by_key(at(key))
				out.push a if a
			end
			out
		end
		
		def first
			RedisObject.find_by_key(super)
		end
		
		def last
			RedisObject.find_by_key(super)
		end
		
		def each
			each_index do |key|
				a = RedisObject.find_by_key(at(key))
				yield a if a
			end
		end

		def map(&block)
			objects.map(&block)
		end
		
		def select(&block)
			out = []
			each_index do |key|
				a = RedisObject.find_by_key(at(key))
				out.push(a) if block.call(a)
			end
			out
		end
		
		def delete(obj)
			store.zrem(key,obj)
			super(obj)
		end
		
		def <<(obj)
			store.zadd(key,store.zcount(key,"-inf", "+inf"),obj)
			super(obj)
		end
		alias_method :push, :<<
		
		def save
		end
		
		def class_const
			Object.const_get(@name.to_s.classify.to_sym)
		end
		
		def key
			"#{@parent ? "#{@parent.key}:" : ""}COLLECTION:#{@name}"
		end
		
		class << self
			
			def load(name,parent)
				out = new(name,parent)
				out.replace store.zrange(out.key,0,-1)
				out
			end
			
			private
			
			def store
				@@store ||= RedisObject.store
			end
			
		end
		
		private
		
		def store
			@@store ||= RedisObject.store
		end
		
	end
	
end
