require 'active_support/inflector'
require 'active_support/core_ext/date_time/conversions'
require 'yajl'
require 'set'

require "redis_object/storage"
require "redis_object/ext/list_enumerator"

require "redis_object/ext/script_cache"
require "redis_object/base"
require "redis_object/matchers"
require "redis_object/inheritance_tracking"
require "redis_object/storage"
require "redis_object/keys"
require "redis_object/types"
require "redis_object/defaults"
require "redis_object/collection"
require "redis_object/indices"
require "redis_object/timestamps"
require "redis_object/experimental/dumping"
require "redis_object/ext/views"
require "redis_object/ext/view_caching"
require "redis_object/ext/triggers"
require "redis_object/ext/filters"
require "redis_object/ext/benchmark"

module Seabright
	class RedisObject
		
		include Seabright::Filters
		include Seabright::ObjectBase
		include Seabright::Matchers
		include Seabright::InheritanceTracking
		include Seabright::CachedScripts
		include Seabright::Storage
		include Seabright::Keys
		include Seabright::DefaultValues
		include Seabright::Indices
		include Seabright::Collections
		include Seabright::Types
		include Seabright::Triggers
		include Seabright::Views
		include Seabright::ViewCaching
		include Seabright::Timestamps
		include Seabright::Benchmark
		include Seabright::Dumping
		
	end
end

require "redis_object/logger"

::RedisObject = Seabright::RedisObject