module Seabright
	module ObjectBase
		
		def initialize(ident={})
			if ident && (ident.class == String || (ident.class == Symbol && (ident = ident.to_s)))
				load(ident.dup)
			elsif ident && ident.class == Hash
				ident[id_sym] ||= generate_id
				if load(ident[id_sym])
					mset(ident.dup)
				end
			end
			self
		end
		
		def new_id(complexity = 8)
			self.class.new_id(complexity)
		end
		
		def generate_id
			self.class.generate_id
		end
		
		def reserve(k)
			self.class.reserve(k)
		end
		
		def id
			@id || get(id_sym) || set(id_sym, generate_id)
		end
		
		def load(o_id)
			@id = clean_id(o_id)
			true
		end
		
		def clean_id(i)
			self.class.clean_id(i)
		end
		
		def save
			set(:class, self.class.name)
			set(id_sym,clean_id(id))
			set(:key, key)
			store.sadd(self.class.plname, key)
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
			filter_gotten_value(k, (cached_hash_values[k.to_s] || _get(k)))
		end
		
		def filter_gotten_value(k,v)
			self.class.get_filters.inject(v) do |acc, filter|
				filter.call(self, k, acc)
			end
		end
		
		def _get(k)
			if is_ref_key?(k) && (v = get_reference(store.hget(hkey, k.to_s)))
				define_setter_getter(k)
			elsif v = store.hget(hkey, k.to_s)
				define_setter_getter(k)
			end
			v
		end
		
		def [](k)
			get(k)
		end
		
		def is_set?(k)
			store.hexists(hkey, k.to_s)
		end
		
		def mset(dat)
			dat = self.class.mset_filters.inject(dat) do |acc,filter|
				filter.call(self, acc)
			end
			store.hmset(hkey, *(dat.inject([]){|acc,(k,v)| acc << [k,v] }.flatten))
			cached_hash_values.merge!(dat)
			dat.each do |k,v|
				define_setter_getter(k)
			end
			dat
		end
		
		def define_setter_getter(key)
			define_access(key) do
				get(key)
			end
			define_access("#{key.to_s}=") do |val|
				set(key,val)
			end
		end
		
		def undefine_setter_getter(key)
			undefine_access(key)
			undefine_access("#{key.to_s}=")
		end
		
		def set(k,v)
			(k,v) = self.class.set_filters.inject([k,v]) do |acc,filter|
				filter.call(self,*acc) unless acc.nil? or acc[0].nil?
			end
			return nil if k.nil?
			return set_ref(k,v) if v.is_a?(RedisObject)
			store.hset(hkey, k.to_s, v.to_s)
			cached_hash_values[k.to_s] = v
			define_setter_getter(k)
			v
		end
		
		def set_ref(k,v)
			return unless v.is_a?(RedisObject)
			track_ref_key(k)
			store.hset(hkey, k.to_s, v.hkey)
			cached_hash_values[k.to_s] = v
			define_setter_getter(k)
			v
		end
		
		def track_ref_key(k)
			store.sadd(ref_field_key, k.to_s)
		end
		
		def is_ref_key?(k)
			if store.sismember(ref_field_key,k.to_s)
				return true
			end
			false
		end
		
		def get_reference(hkey)
			if o = RedisObject.find_by_key(hkey)
				return o
			end
			nil
		end
		
		def setnx(k,v)
			(k,v) = self.class.set_filters.inject([k,v]) do |acc,filter|
				filter.call(self,*acc)
			end
			if success = store.hsetnx(hkey, k.to_s, v.to_s)
				cached_hash_values[k.to_s] = v
				define_setter_getter(k)
			end
			success
		end
		
		def []=(k,v)
			set(k,v)
		end
		
		def unset(*k)
			store.hdel(hkey, k.map(&:to_s))
			k.each do |ky|
				cached_hash_values.delete ky.to_s
				undefine_setter_getter(ky)
			end
		end
		
		private
		
		SetPattern = /=$/.freeze
		
		def method_missing(sym, *args, &block)
			super if sym == :class
			if sym.to_s =~ SetPattern
				return super if args.size > 1
				send(:set,sym.to_s.gsub(SetPattern,'').to_sym,*args)
			else
				return super if !args.empty?
				send(:get,sym)
			end
		end
		
		def id_sym(cls=nil)
			self.class.id_sym(cls)
		end
		
		# Not used yet...
		# def load_all_hash_values
		# 	@cached_hash_values = store.hgetall(hkey)
		# 	cached_hash_values.keys.dup.each do |key|
		# 		next if key == "class"
		# 		define_setter_getter(key)
		# 	end
		# end
		# 
		def cached_hash_values
			@cached_hash_values ||= {}
		end
		
		def define_access(key,&block)
			return if self.respond_to?(key.to_sym)
			metaclass = class << self; self; end
			metaclass.send(:define_method, key.to_sym, &block)
		end
		
		def undefine_access(key)
			return unless self.respond_to?(key.to_sym)
			metaclass = class << self; self; end
			metaclass.send(:remove_method, key.to_sym) rescue nil
		end
		
		module ClassMethods
			
			def action_filters
				@@action_filters ||= {}
			end
			
			def set_filters
				action_filters[:set] ||= []
			end
			
			def filter_sets(&block)
				set_filters << block
			end
			
			def mset_filters
				action_filters[:mset] ||= []
			end
			
			def filter_msets(&block)
				mset_filters << block
			end
			
			def get_filters
				action_filters[:get] ||= []
			end
			
			def filter_gets(&block)
				get_filters << block
			end
			
			def clean_id(i)
				i.to_s.gsub(/.*:/,'').gsub(/_h$/,'')
			end
			
			def generate_id
				v = new_id
				while exists?(v) do
					Log.verbose "[RedisObject] Collision at id: #{v}"
					v = new_id
				end
				Log.verbose "[RedisObject] Reserving key: #{v}"
				reserve(v)
				v
			end
			
			def reserve(k)
				store.set(reserve_key(k),Time.now.to_s)
			end
			
			def new_id(complexity = 8)
				rand(36**complexity).to_s(36)
			end
			
			def cname
				name
			end
			
			def plname
				cname.pluralize
			end
			
			def all
				kys = store.smembers(plname)
				ListEnumerator.new(kys) do |y|
					kys.each do |member|
						if a = find_by_key(hkey(member))
							y << a
						else
							Log.debug "[#{name}] Object listed but not found: #{member}"
							store.srem(plname,member)
						end
					end
				end
			end
			
			def recollect!
				store.keys("#{name}:*_h").each do |ky|
					store.sadd(plname, clean_id(ky))
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
			
			def exists?(k)
				store.exists(self.hkey(k)) || store.exists(self.reserve_key(k))
			end
			
			def create(ident={})
				obj = new(ident)
				obj.save
				obj
			end
			
			def use_dbnum(db=0)
				@dbnum = db
			end
			
			def dbnum
				@dbnum ||= 0
			end
			
			def find_by_key(k)
				if store.exists(k) && (cls = store.hget(k,:class))
					return deep_const_get(cls.to_sym,Object).new(store.hget(k,id_sym(cls)))
				end
				nil
			end
			
			def deep_const_get(const,base=nil)
				if Symbol === const
					const = const.to_s
				else
					const = const.to_str.dup
				end
				base ||= const.sub!(/^::/, '') ? Object : self
				const.split(/::/).inject(base) { |mod, name| mod.const_get(name) }
			end
			
			def save_all
				all.each do |obj|
					obj.save
				end
				true
			end
			
			def id_sym(cls=nil)
				_old_id_sym(cls)
			end
			
			def _new_id_sym(cls=self.name)
				(cls || self.name).foreign_key.to_sym
			end
			
			def convert_old_id_syms!
				ol = _old_id_sym
				nw = id_sym
				each do |obj|
					if obj.is_set?(ol)
						obj.set(nw,get(ol))
						obj.unset(ol)
					end
				end
			end
			
			def _old_id_sym(cls=self.name)
				"#{(cls || self.name).split('::').last.downcase}_id".to_sym
			end
			
			def describe
				all_keys.inject({}) do |acc,(k,v)|
					acc[k.to_sym] ||= [:string, 0]
					acc[k.to_sym][1] += 1
					acc
				end
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end
