module Seabright
  class ExternalIndex
    
    def initialize
    end
    
    class << self
      
      def buildthisout
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