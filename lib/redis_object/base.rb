module Seabright
	module ObjectBase
		
		def initialize(ident={})
			if ident && (ident.class == String || (ident.class == Symbol && (ident = ident.to_s)))# && ident.gsub!(/.*:/,'') && ident.length > 0
				load(ident.dup)
			elsif ident && ident.class == Hash
				ident[id_sym] ||= generate_id
				if load(ident[id_sym])
					mset(ident.dup)
				end
			end
			self
		end
		
		def save
			set(:class, self.class.name)
			set(id_sym,id.gsub(/.*:/,''))
			set(:key, key)
			_save
		end
		
		def delete!
			_delete!
			dereference_all!
			nil
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
			@id = o_id
			true
		end
		
		def dereference_all!
			
		end
		
		def inspect
			raw
		end
		
		def actual
			raw
		end
		
		def is_set?(k)
			_is_set?(k)
		end
		
		def set(k,v)
			return nil if k.nil?
			return set_ref(k,v) if v.is_a?(RedisObject)
			_set(k,v)
			cached_hash_values[k.to_s] = v
			define_setter_getter(k)
			v
		end
		
		def set_ref(k,v)
			return unless v.is_a?(RedisObject)
			track_ref_key(k)
			_set_ref(k,v)
			cached_hash_values[k.to_s] = v
			define_setter_getter(k)
			v
		end
		
		def track_ref_key(k)
			_track_ref_key(k)
		end

		def is_ref_key?(k)
			if _is_ref_key?(k)
				return true
			end
			false
		end
		
		def setnx(k,v)
			if success = _setnx(k,v)
				cached_hash_values[k.to_s] = v
				define_setter_getter(k)
			end
			success
		end
		
		def mset(dat)
			_mset dat
			cached_hash_values.merge!(dat)
			dat.each do |k,v|
				define_setter_getter(k)
			end
			dat
		end
		
		def unset(*k)
			_unset(*k)
			k.each do |ky|
				cached_hash_values.delete ky.to_s
				undefine_setter_getter(ky)
			end
		end
		
		def get(k)
			cached_hash_values[k.to_s] ||= getter(k)
		end
		
		def getter(k)
			if is_ref_key?(k) && (v = get_reference(_get(k)))
				define_ref_setter_getter(k)
			elsif v = _get(k)
				define_setter_getter(k)
			end
			v
		end
		
		def [](k)
			get(k)
		end
		
		def define_setter_getter(key)
			define_access(key) do
				get(key)
			end
			define_access("#{key.to_s}=") do |val|
				set(key,val)
			end
		end
		
		def define_ref_setter_getter(key)
			define_access(key) do
				get_reference(key)
			end
			define_access("#{key.to_s}=") do |val|
				set_ref(key,val)
			end
		end
		
		def undefine_setter_getter(key)
			undefine_access(key)
			undefine_access("#{key.to_s}=")
		end
		
		def get_reference(hkey)
			if o = self.class.find_by_key(hkey)
				return o
			end
			nil
		end
		
		def []=(k,v)
			set(k,v)
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
			metaclass.send(:remove_method, key.to_sym)
		end
		
		module ClassMethods
			
			def all
				kys = all_keys
				ListEnumerator.new(kys) do |y|
					kys.each do |member|
						if a = find_by_key(hkey(member))
							y << a
						else
							Log.debug "[#{name}] Object listed but not found: #{member}"
							untrack_key member
						end
					end
				end
			end
			
			def first
				if m = all_keys
				 self.grab(m.first)
				else
					nil
				end
			end
			
			def match(pkt)
				kys = match_keys(pkt)
				ListEnumerator.new(kys) do |y|
					kys.each do |k|
						y << find(k)
					end
				end
			end
			
			def grab(ident)
				case ident
				when String, Symbol
					return grab_id(ident)
				when Hash
					return match(ident)
				end
				nil
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
			
			def new_id(complexity = 8)
				rand(36**complexity).to_s(36)
			end
			
			def cname
				name
			end
			
			def plname
				cname.pluralize
			end
			
			def each
				all.each do |o|
					yield o
				end
			end
						
			def find(ident)
				grab(ident)
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
