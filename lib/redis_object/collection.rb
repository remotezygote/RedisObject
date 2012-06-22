module Seabright
	
	module Collections
		
		def dump(prnt=nil)
			require "utf8_utils"
			out = ["puts \"Creating: #{id}\""]
			s_id = (prnt ? "#{prnt.id} #{id}" : id).gsub(/\W/,"_")
			out << "a#{s_id} = #{self.class.cname}.new(#{actual.to_s.tidy_bytes},#{prnt.id})"
			collections.each do |col|
				col.each do |sobj|
					out << sobj.dump(self)
				end
			end
			out << "a#{prnt.id.gsub(/\W/,"_")} << a#{s_id}" if prnt
			out << "a#{s_id}.save"
			out.join("\n")
		end
		
		def hkey_col(ident = nil, prnt = nil)
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
			if col = collections[obj.class.plname.downcase.to_sym]
				col.delete obj.hkey
			end
		end
		
		def <<(obj)
			obj.parent = self
			obj.save
			name = obj.class.plname.downcase.to_sym
			store.sadd hkey_col, name
			collections[name] ||= Seabright::Collection.load(name,self)
			collections[name] << obj.hkey
		end
		alias_method :push, :<<
		
		def get(k)
			if collections[k.to_s]
				get_collection(k.to_s)
			else
				super(k)
			end
		end
		
		def get_collection(name)
			collections[name.to_s] ||= Collection.load(name,self)
			collections[name.to_s]
		end
		
		def collections
			@collections ||= {}
		end
		
		def set(k,v)
			@data ? super(k,v) : collections[k.to_sym] ? get_collection(k).replace(v) : super(k,v)
			v
		end
		
		module ClassMethods
			
			def hkey_col(ident = id, prnt = nil)
				"#{hkey(ident,prnt)}:collections"
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
	
	
	class Collection < Array
		
		def initialize(name,parent)
			@name = name
			@parent = parent
		end
		
		def indexed(index,num=5,reverse=false)
			out = []
			store.send(reverse ? :zrevrange : :zrange,index_key(index), 0, num).each do |member|
				if a = class_const.find_by_key(member)
					out << a
				else
					store.zrem(index_key(index),member)
				end
			end
			out
		end
		
		def index_key(index)
			"#{@parent.key}:#{class_const.name.pluralize}::#{index}"
		end
		
		def item_key(k)
			"#{class_const}:#{k}_h"
		end
		
		def find(k)
			real_at item_key(k)
			# each do |a|
			# 	return a if a.id == k && include?(a.hkey)
			# end
			# return nil
		end
		alias_method :[], :find
		
		def real_at(key)
			class_const.find_by_key(key)
		end
		
		# def [](idx)
		# 	class_const.find_by_key(at(idx))
		# end
		
		def objects
			out = []
			each_index do |key|
				a = class_const.find_by_key(at(key))
				out.push a if a
			end
			out
		end
		
		def first
			class_const.find_by_key(super)
		end
		
		def last
			class_const.find_by_key(super)
		end
		
		def each
			each_index do |key|
				a = class_const.find_by_key(at(key))
				yield a if a
			end
		end
		
		def select(&block)
			out = []
			each_index do |key|
				a = class_const.find_by_key(at(key))
				out.push(a) if block.call(a)
			end
			out
		end
		
		def delete(obj)
			store.srem(key,obj)
			super(obj)
		end
		
		def <<(obj)
			store.sadd(key,obj)
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
				out = self.new(name,parent)
				out.replace store.smembers(out.key)
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