$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'rubygems'
require 'test/unit'
require 'rspec'

require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start do
	add_filter "_spec.rb"
	add_group "Extensions", "lib/redis_object/ext/"
	add_group "Experimental", "lib/redis_object/experimental/"
end

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
RedisObject.configure_store({adapter:'Redis', db:ENV['TEST_DB']},:global,:alias)