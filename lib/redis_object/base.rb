module Seabright
	module ObjectBase
		
		def initialize(ident={})
			if ident && (ident.class == String || (ident.class == Symbol && (ident = ident.to_s)))
				load(ident)
			elsif ident && ident.class == Hash
				ident[id_sym] ||= generate_id
				if load(ident[id_sym])
					ident.each do |k,v|
						set(k,v)
					end
				end
			end
		end
		
		def new_id
			self.class.new_id
		end
		
		def generate_id
			v = new_id
			while self.class.exists?(v) do
				puts "[RedisObject] Collision at id: #{v}" if Debug.verbose?
				v = new_id
			end
			puts "[RedisObject] Reserving key: #{v}" if Debug.verbose?
			reserve(v)
			v
		end
		
		def reserve(k)
			store.set(reserve_key(k),Time.now.to_s)
		end
		
		def to_json
			require 'yajl'
			Yajl::Encoder.encode(actual)
		end
		
		def dump
			require "utf8_utils"
			out = ["puts \"Creating: #{id}\""]
			s_id = id.gsub(/\W/,"_")
			out << "a#{s_id} = #{self.class.cname}.new(#{actual.to_s.tidy_bytes})"
			out << "a#{s_id}.save"
			out.join("\n")
		end
		
		def id
			@id || get(id_sym) || set(id_sym, generate_id)
		end
		
		def load(o_id)
			@id = o_id
			true
		end
		
		def save
			set(:class, self.class.name)
			set(id_sym,id)
			set(:key, key)
			store.sadd(self.class.cname.pluralize, key)
			store.del(reserve_key)
		end
		
		def delete!
			store.del key
			store.srem(self.class.plname, key)
			store.smembers(ref_key).each do |k|
				if self.class.find_by_key(k)
					
				end
			end
		end
		
		def raw
			store.hgetall(hkey).inject({}) {|acc,k| acc[k[0].to_sym] = enforce_format(k[0],k[1]); acc }
		end
		alias_method :inspect, :raw
		alias_method :actual, :raw
		
		def get(k)
			val = store.hget(hkey, k.to_s)
		end
		alias_method :[], :get
		
		def set(k,v)
			store.hset(hkey, k.to_s.gsub(/\=$/,''), v)
			v
		end
		alias_method :[]=, :set
		
		def unset(*k)
			store.hdel(hkey,*k)
		end
		# alias_method :delete, :unset
		
		private
		
		def method_missing(sym, *args, &block)
			sym.to_s =~ /=$/ ? set(sym,*args) : get(sym)
		end
		
		def id_sym(cls=nil)
			"#{(cls || self.class.cname).split('::').last.downcase}_id".to_sym
		end
		
		module ClassMethods
			
			def new_id
				rand(36**8).to_s(36)
			end
			
			def cname
				@cname = self.name.split('::').last
			end
			
			def plname
				@plname ||= cname.pluralize
			end
			
			def all
				out = []
				store.smembers(plname).each do |member|
					if a = self.find(member)
						out << a
					else
						# store.srem(plname,member)
					end
				end
				out
			end
			
			def first
				if m = store.smembers(plname)
				 self.grab(m.first)
				else
					nil
				end
			end
			
			def each
				store.smembers(plname).each do |member|
					if a = grab(member)
						yield a
					end
				end
			end
			
			def grab(ident)
				if ident.class == String
					return store.exists(self.hkey(ident)) ? self.new(ident) : nil
				elsif ident.class == Hash
					each do |obj|
						good = true
						ident.each do |k,v|
							good = false if !obj[k.to_sym] || obj[k.to_sym]!=v
						end
						return obj if good
					end
				end
				nil
			end
			alias_method :find, :grab
			
			def exists?(k)
				store.exists(self.hkey(k)) || store.exists(self.reserve_key(k))
			end
			
			def create(ident)
				obj = new(ident)
				obj.save
				obj
			end
			
			def dump
				out = []
				self.all.each do |obj|
					out << obj.dump
				end
				out.join("\n")
			end
			
			def use_dbnum(db=0)
				@dbnum = db
			end
			
			def dbnum
				@dbnum ||= 0
			end
			
			def find_by_key(k)
				if store.exists(k) && (cls = store.hget(k,:class))
					o_id = store.hget(k,id_sym(cls))
					return deep_const_get(cls.to_sym).new(o_id)
				end
				nil
			end
			
			def deep_const_get(const)
				if Symbol === const
					const = const.to_s
				else
					const = const.to_str.dup
				end
				if const.sub!(/^::/, '')
					base = Object
				else
					base = self
				end
				const.split(/::/).inject(base) { |mod, name| mod.const_get(name) }
			end
			
			def save_all
				all.each do |obj|
					obj.save
				end
				true
			end
			
			def id_sym(cls=nil)
				"#{(cls || cname).split('::').last.downcase}_id".to_sym
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end