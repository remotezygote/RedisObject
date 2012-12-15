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
			# TODO: Here's an example of dynamic method creation - should do this instead of method_missing + module intercepts...
			# %w[report alert error summary].each do |kind|
			# 	      class_eval <<-END
			# 	        if "#{kind}" == "summary"
			# 	          def summaries
			# 	            data_for_server[:summaries]
			# 	          end
			# 	        else
			# 	          def #{kind}s
			# 	            data_for_server[:#{kind}s]
			# 	          end
			# 	        end
			# 
			# 	        if "#{kind}" == "report"
			# 	          def report(new_entry)
			# 	            reports << new_entry
			# 	          end
			# 	        elsif "#{kind}" == "summary"
			# 	          def summary(new_entry)
			# 	            summaries << new_entry
			# 	          end
			# 	        else
			# 	          def #{kind}(*fields)
			# 	            #{kind}s << ( fields.first.is_a?(Hash) ?
			# 	                          fields.first :
			# 	                          {:subject => fields.first, :body => fields.last} )
			# 	          end
			# 	        end
			# 	        alias_method :add_#{kind}, :#{kind}
			# 	      END
			# 	    end
			true
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
			store.sismember(hkey_col,name.to_s)
		end
		
		def get_collection(name)
			collections[name.to_s] ||= Collection.load(name,self)
			collections[name.to_s]
		end
		
		def collections
			@collections ||= {}
		end
		
		def mset(dat)
			dat.select! {|k,v| !collections[k.to_s] }
			super(dat)
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
		
		def remove!
			@parent.remove_collection! @name
		end
		
		def latest
			indexed(:created_at,5,true).first
		end
		
		def indexed(idx,num=-1,reverse=false)
			keys = keys_by_index(idx,num,reverse)
			out = Enumerator.new do |y|
				keys.each do |member|
					if a = RedisObject.find_by_key(member)
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
			"zintersect_temp"
		end
		
		def keys_by_index(idx,num=-1,reverse=false)
			keys = nil
			store.multi do
				store.zinterstore(temp_key, [index_key(idx), key], {:weights => ["1","0"]})
				keys = store.send(reverse ? :zrevrange : :zrange, temp_key, 0, num)
				store.del temp_key
			end
			Enumerator.new do |y|
				keys.value.each do |member|
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
			elsif k.is_a? Number
				return real_at(at(k))
			end
			return nil
		end
		alias_method :[], :find
		
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
			RedisObject.find_by_key(key)
		end
		
		# def [](idx)
		# 	class_const.find_by_key(at(idx))
		# end
		
		def objects
			each.to_a
		end
		
		def first
			RedisObject.find_by_key(super)
		end
		
		def last
			RedisObject.find_by_key(super)
		end
		
		def each
			out = Enumerator.new do |y|
				each_index do |key|
					if a = RedisObject.find_by_key(at(key))
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
				unless a = RedisObject.find_by_key(at(key))
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
					if (a = RedisObject.find_by_key(at(key))) && block.call(a)
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
		alias_method :push, :<<
		
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
