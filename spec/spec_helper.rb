$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'rubygems'
require 'test/unit'
require 'rspec'
require 'redis_object'

class DebugMode
	def initialize(o=nil); @opts = o; end
	def verbose?; debug? && !!@opts[:verbose]; end
	def debug?; !!@opts; end
end
Debug = if ENV['DEBUG']
		require 'debugger'
		DEBUG = true
		DebugMode.new(verbose:true)
	else
		DEBUG = false
		DebugMode.new
	end

raise 'must specify TEST_DB' unless ENV['TEST_DB']
RedisObject.configure_store({adapter:'Redis', db:ENV['TEST_DB']})
