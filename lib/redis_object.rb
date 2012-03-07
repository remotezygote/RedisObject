require "redis_object/redis_pool"
require "redis_object/collection"
require 'active_support/inflector'
require 'active_support/core_ext/date_time/conversions'

module Seabright
  class RedisObject

    @@indices = []
    @@sort_indices = [:created_at,:updated_at]
    @@field_formats = {
      :created_at => :format_date,
      :updated_at => :format_date
    }
    @@time_irrelevant = false
    
    def initialize(ident, prnt = nil)
      if prnt && prnt.class != String
        @parent = prnt
        @parent_id = prnt.hkey
      else
        @parent_id = prnt
      end
      @collections = {}
      if ident && ident.class == String
        load(ident)
      elsif ident && ident.class == Hash
        ident[id_sym] ||= generate_id
        if load(ident[id_sym])
          @data = ident
        end
      end
      # enforce_formats
    end
    
    def new_id
      rand(36**6).to_s(36)
    end
    
    def generate_id
      v = new_id
      while self.class.exists?(v) do
        puts "[RedisObject] Collision at id: #{v}"
        v = new_id
      end
      v
    end
    
    def save_history?
      save_history || self.class.save_history?
    end
    
    def store_image
      redis.zadd history_key, Time.now.to_i, to_json
    end
    
    def history(num=5,reverse=false)
      parser = Yajl::Parser
      redis.send(reverse ? :zrevrange : :zrange, history_key, 0, num).collect do |member|
        parser.parse(member)
      end
    end
    
    def to_json
      require 'yajl'
      Yajl::Encoder.encode(actual)
    end
    
    def enforce_format(k,v)
      v && @@field_formats[k.to_sym] ? send(@@field_formats[k.to_sym],v) : v
    end
    
    def format_date(val)
      val.instance_of?(DateTime) ? val : DateTime.parse(val)
    end
    
    def format_number(val)
      val.to_i
    end
    
    def format_boolean(val)
      !!val
    end
    
    def dump(prnt=nil)
      require "utf8_utils"
      out = ["puts \"Creating: #{id}\""]
      s_id = (prnt ? "#{prnt.id} #{id}" : id).gsub(/\W/,"_")
      out << "a#{s_id} = #{self.class.cname}.new(#{actual.to_s.tidy_bytes},#{prnt.id})"
      @collections.each do |col|
        col.each do |sobj|
          out << sobj.dump(self)
        end
      end
      out << "a#{prnt.id.gsub(/\W/,"_")} << a#{s_id}" if prnt
      out << "a#{s_id}.save"
      out.join("\n")
    end
    
    def key(ident = id, prnt = parent)
      "#{prnt ? prnt.class==String ? "#{prnt}:" : "#{prnt.key}:" : ""}#{self.class.cname}:#{ident.gsub(/^.*:/,'')}"
    end
    
    def hkey(ident = nil, prnt = nil)
      "#{key}_h"
    end
    
    def history_key(ident = nil, prnt = nil)
      "#{key}_history"
    end
    
    def hkey_col(ident = nil, prnt = nil)
      "#{hkey}:collections"
    end
    
    def ref_key(ident = nil, prnt = nil)
      "#{hkey}:backreferences"
    end
    
    def parent
      @parent ||= @parent_id ? find_by_key(@parent_id) : nil
    end
    
    def parent=(obj)
      @parent = obj.class == String ? self.find_by_key(obj) : obj
      if @parent
        @parent_id = obj.hkey
        set(:parent, @parent_id)
      end
    end
    
    def id
      @id || set(:id_sym, get(:id_sym) || generate_id)
    end
    
    def load(o_id)
      @id = o_id
      redis.smembers(hkey_col).each do |name|
        @collections[name] = Seabright::Collection.load(name,self)
      end
      true
    end
    
    def save
      set(:class, self.class.name)
      set(id_sym,id)
      set(:key, key)
      if @data
        saving = @data
        @data = false
        saving.each do |k,v|
          set(k,v)
        end
      end
      update_timestamps
      redis.sadd(self.class.cname.pluralize, key)
      @collections.each do |k,col|
        col.save
      end
      save_indices
      store_image if save_history?
    end
    
    def save_indices
      @@indices.each do |indx|
        indx.each do |key,idx|
          
        end
      end
      @@sort_indices.each do |idx|
        redis.zadd(index_key(idx), send(idx).to_i, hkey)
      end
    end
    
    def index_key(idx,extra=nil)
      "#{parent ? "#{parent.key}:" : ""}#{self.class.plname}::#{idx}#{extra ? ":#extra" : ""}"
    end
    
    def delete!
      redis.del key
      redis.srem(self.class.plname, key)
      if parent
        parent.delete_child self
      end
      redis.smembers(ref_key).each do |k|
        if self.class.find_by_key(k)
          
        end
      end
    end
    
    def delete_child(obj)
      if col = @collections[obj.class.plname.downcase.to_sym]
        col.delete obj.hkey
      end
    end
    
    def <<(obj)
      obj.parent = self
      obj.save
      name = obj.class.plname.downcase.to_sym
      redis.sadd hkey_col, name
      @collections[name] ||= Seabright::Collection.load(name,self)
      @collections[name] << obj.hkey
    end
    alias_method :push, :<<
    
    def reference(obj)
      name = obj.class.plname.downcase.to_sym
      redis.sadd hkey_col, name
      @collections[name] ||= Seabright::Collection.load(name,self)
      @collections[name] << obj.hkey
      obj.referenced_by self
    end
    
    def referenced_by(obj)
      redis.sadd(ref_key,obj.hkey)
    end
    
    def raw
      redis.hgetall(hkey).inject({}) {|acc,k| acc[k[0]] = enforce_format(k[0],k[1]); acc }
    end
    alias_method :inspect, :raw
    alias_method :actual, :raw
    
    # def inspect
    #   raw
    # end
    # 
    # def actual
    #   raw #.inject({}) {|acc,(k,v)| acc[k] = v if ![:collections, :key].include?(k) && (!@data[:collections] || !@data[:collections].include?(k.to_s)); acc }
    # end
    # 
    def get(k)
      if @collections[k.to_s] 
        get_collection(k.to_s)
      else
        val = @data ? @data[k] : redis.hget(hkey, k.to_s)
        enforce_format(k,val)
      end
    end
    alias_method :[], :get
    
    def get_collection(name)
      @collections[name.to_s] ||= Seabright::Collection.load(name,self)
    end
    
    def set(k,v)
      @data ? @data[k] = v : @collections[k.to_sym] ? get_collection(k).replace(v) : redis.hset(hkey, k.to_s.gsub(/\=$/,''), v)
      v
    end
    
    private
    
    def redis
      @@redis ||= self.class.redis
    end
    
    def method_missing(sym, *args, &block)
      sym.to_s =~ /=$/ ? set(sym,*args) : get(sym)
    end
    
    def id_sym(cls=nil)
      "#{(cls || self.class.cname).downcase}_id".to_sym
    end
    
    def update_timestamps
      return if @@time_irrelevant
      set(:created_at, Time.now) if !get(:created_at)
      set(:updated_at, Time.now)
    end
    
    class << self
      
      def indexed(index,num=5,reverse=false)
        out = []
        redis.send(reverse ? :zrevrange : :zrange, "#{self.plname}::#{index}", 0, num).each do |member|
          if a = self.find_by_key(member)
            out << a
          else
            # redis.zrem(self.plname,member)
          end
        end
        out
      end
      
      def recently_created(num=5)
        self.indexed(:created_at,num,true)
      end
      
      def recently_updated(num=5)
        self.indexed(:updated_at,num,true)
      end
      
      def cname
        @cname = self.name.split('::').last
      end
      
      def plname
        @plname ||= cname.pluralize
      end
      
      def all
        out = []
        redis.smembers(plname).each do |member|
          if a = self.find(member)
            out << a
          else
            # redis.srem(plname,member)
          end
        end
        out
      end
      
      def find(ident,prnt=nil)
        redis.exists(self.hkey(ident,prnt)) ? self.new(ident,prnt) : nil
      end
      
      def exists?(k)
        redis.exists self.hkey(k)
      end
      
      def create(ident)
        obj = self.class.new(ident)
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
      
      def index(opts)
        @@indices << opts
      end
      
      def time_matters_not!
        @@time_irrelevant = true
        @@sort_indices.delete(:created_at)
        @@sort_indices.delete(:updated_at)
      end
      
      def sort_by(k)
        @@sort_indices << (k)
      end
      
      def date(k)
        @@field_formats[k] = :format_date
      end
      
      def number(k)
        @@field_formats[k] = :format_number
      end
      
      def bool(k)
        @@field_formats[k] = :format_boolean
      end
      
      def save_history!(v=true)
        @@save_history = v
      end
      
      def save_history?
        @@save_history ||= false
      end
      
      def key(ident, prnt = nil)
        "#{prnt ? prnt.class==String ? "#{prnt}:" : "#{prnt.key}:" : ""}#{cname}:#{ident.gsub(/^.*:/,'')}"
      end
      
      def hkey(ident = id, prnt = nil)
        "#{key(ident,prnt)}_h"
      end
      
      def history_key(ident = id, prnt = nil)
        "#{key(ident,prnt)}_history"
      end
      
      def hkey_col(ident = id, prnt = nil)
        "#{hkey(ident,prnt)}:collections"
      end
      
      def find_by_key(k)
        if cls = redis.hget(k,:class) 
          o_id = redis.hget(k,id_sym(cls))
          prnt = redis.hget(k,:parent)
          if redis.exists(k)
            return deep_const_get(cls.to_sym).new(o_id,prnt)
          end
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
      
      def redis
        @@redis ||= Seabright::RedisPool.connection
      end
      
      def id_sym(cls=nil)
        "#{(cls || cname).downcase}_id".to_sym
      end
      
    end
    
  end
end