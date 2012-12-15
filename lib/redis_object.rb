require 'active_support/inflector'
require 'active_support/core_ext/date_time/conversions'
require 'yajl'

require "redis_object/storage"

require "redis_object/base"
require "redis_object/storage"
require "redis_object/keys"
require "redis_object/types"
require "redis_object/defaults"
require "redis_object/collection"
require "redis_object/indices"
require "redis_object/timestamps"
require "redis_object/history"
require "redis_object/ext/triggers"
require "redis_object/ext/benchmark"

module Seabright
	class RedisObject
		
		include Seabright::ObjectBase
		include Seabright::Storage
		include Seabright::Keys
		include Seabright::Types
		include Seabright::DefaultValues
		include Seabright::Collections
		include Seabright::Indices
		include Seabright::Timestamps
		include Seabright::History
		include Seabright::Triggers
		include Seabright::Benchmark
		
	end
end

::RedisObject = Seabright::RedisObject