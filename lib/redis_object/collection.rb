module Seabright
  class Collection < Array
  
    def initialize(name,parent)
      @name = name
      @parent = parent
    end
  
    def indexed(index,num=5,reverse=false)
      out = []
      redis.send(reverse ? :zrevrange : :zrange,index_key(index), 0, num).each do |member|
        if a = class_const.find_by_key(member)
          out << a
        else
          redis.zrem(index_key(index),member)
        end
      end
      out
    end
  
    def index_key(index)
      "#{@parent.key}:#{class_const.name.pluralize}::#{index}"
    end
  
    def find(key)
      each do |a|
        return a if a.id == key && include?(a.hkey)
      end
      return nil
    end
  
    def real_at(key)
      class_const.find_by_key(key)
    end

		def [](idx)
			class_const.find_by_key(at(idx))
		end
  
    def objects
      out = []
      each_index do |key|
        a = class_const.find_by_key(at(key))
        out.push a if a
      end
      out
    end
  
    def each
      each_index do |key|
        a = class_const.find_by_key(at(key))
        yield a if a
      end
    end
    
    def delete(obj)
      redis.srem(key,obj)
      super(obj)
    end
  
    def <<(obj)
      redis.sadd(key,obj)
      super(obj)
    end
    alias_method :push, :<<
  
    def save
      # uniq!
      # puts "Saving #{@name} collection to #{key}"
      # each do |itm|
      #   redis.sadd(key,itm)
      # end
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
        out.replace redis.smembers(out.key)
        out
      end
      
      private 
      
      def redis
        @@redis ||= Seabright::RedisPool.connection
      end
      
    end
    
    private
  
    def redis
      @@redis ||= self.class.redis
    end
  
  end

end