require 'active_support/inflector'
require 'active_support/core_ext/date_time/conversions'
require 'yajl'
require 'set'

require "redis_object/storage"
require "redis_object/ext/list_enumerator"

require "redis_object/ext/script_cache"
require "redis_object/base"
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

require "defined"
Defined.enable!

module Seabright
	
	BaseModules = [
		Filters,
		ObjectBase,
		InheritanceTracking,
		Keys,
		Types,
		DefaultValues,
		Collections,
		Triggers,
		Indices,
		Views,
		ViewCaching,
		Timestamps,
		Benchmark,
		Dumping,
		Storage
	]
	
	class RedisObject
		
		def base_object
			@ro_bo ||= self.class.base_object
		end
		
		def self.base_object
			Seabright::Storage.const_get(adapter).base_object
		end
		
		def self.inherited(base)
			Seabright::BaseModules.each do |mod|
				base.send(:include, mod)
			end
		end
		
		def self.defined(*args)
			if superclass == RedisObject
				self.send(:include, base_object)
			end
		end
		
		def self.deep_const_get(const,base=nil)
			if Symbol === const
				const = const.to_s
			else
				const = const.to_str.dup
			end
			base ||= const.sub!(/^::/, '') ? Object : self
			const.split(/::/).inject(base) { |mod, name| mod.const_get(name) }
		end
		
	end
end

require "redis_object/logger"

::RedisObject = Seabright::RedisObject