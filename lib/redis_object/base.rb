module Seabright
	module ObjectBase
		
		def initialize(ident={})
			if ident && (ident.class == String || (ident.class == Symbol && (ident = ident.to_s)))# && ident.gsub!(/.*:/,'') && ident.length > 0
				load(ident)
			elsif ident && ident.class == Hash
				ident[id_sym] ||= generate_id
				if load(ident[id_sym])
					mset(ident)
				end
			end
			self
		end
		
		def new_id(complexity = 8)
			self.class.new_id(complexity)
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
			set(id_sym,id.gsub(/.*:/,''))
			set(:key, key)
			store.sadd(self.class.cname.pluralize, key)
			store.del(reserve_key)
		end
		
		def delete!
			store.del key
			store.del hkey
			store.del reserve_key
			store.srem(self.class.plname, key)
			# store.smembers(ref_key).each do |k|
			# 	if self.class.find_by_key(k)
			# 		
			# 	end
			# end
			dereference_all!
			nil
		end
		
		def dereference_all!
			
		end
		
		def raw
			store.hgetall(hkey).inject({}) {|acc,(k,v)| acc[k.to_sym] = enforce_format(k,v); acc }
		end
		alias_method :inspect, :raw
		alias_method :actual, :raw
		
		def get(k)
			store.hget(hkey, k.to_s)
		end
		alias_method :[], :get
		
		def is_set?(k)
			store.hexists(hkey, k.to_s)
		end
		
		def mset(dat)
			# dat.each do |k,v|
			# 	set(k,v)
			# end
			store.hmset(hkey, *(dat.inject([]){|acc,(k,v)| acc + [k,v] }))
			dat
		end
		
		def set(k,v)
			store.hset(hkey, k.to_s.gsub(/\=$/,''), v)
			v
		end
		alias_method :[]=, :set
		
		def unset(k)
			store.hdel(hkey, k.to_s)
		end
		
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
			
			def new_id(complexity = 8)
				rand(36**complexity).to_s(36)
			end
			
			def cname
				@cname = self.name.split('::').last
			end
			
			def plname
				@plname ||= cname.pluralize
			end
			
			def all
				Enumerator.new do |y|
					store.smembers(plname).each do |member|
						if a = RedisObject.find_by_key(hkey(member))
							y << a
						else
							puts "[#{name}] Object listed but not found: #{member}" if DEBUG
							# store.srem(plname,member)
						end
					end
				end
			end
			
			def first
				if m = store.smembers(plname)
				 self.grab(m.first)
				else
					nil
				end
			end
			
			def each
				all.each do |o|
					yield o
				end
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
			
			def grab(ident)
				case ident
				when String, Symbol
					return store.exists(self.hkey(ident.to_s)) ? self.new(ident.to_s) : nil
				when Hash
					return match(ident)
				end
				nil
			end
			alias_method :find, :grab
			
			def exists?(k)
				store.exists(self.hkey(k)) || store.exists(self.reserve_key(k))
			end
			
			def create(ident={})
				obj = new(ident)
				obj.save
				obj
			end
			
			def dump
				out = []
				each do |obj|
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
