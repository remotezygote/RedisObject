$ScriptSHAMap = {}

module Seabright
	
	class RedisObject
		module ScriptSources; end
	end
	
	module CachedScripts
		
		def run_script(name,keys=[],args=[],source=nil)
			self.class.run_script(name,keys,args,source,store)
		end
		
		module ClassMethods
			
			NoScriptError = "NOSCRIPT No matching script. Please use EVAL.".freeze
			
			def run_script(name,keys=[],args=[],source=nil,stor=nil)
				@tmp_store = stor if stor
				@rescue_recurse ||= 0
				begin
					out = (@tmp_store || store).evalsha(get_script_sha(name,source),keys,args)
				rescue Redis::CommandError => e
					if e.message == NoScriptError && @rescue_recurse < 3
						Log.debug "Rescuing NOSCRIPT error for #{name} - running again..."
						untrack_script name
						@rescue_recurse += 1
						out = (@tmp_store || store).evalsha(get_script_sha(name,source),keys,args)
					else
						@rescue_recurse = 0
						raise e
					end
				end
				@rescue_recurse = 0
				remove_instance_variable(:@tmp_store) if @tmp_store
				out
			end
			
			def get_script_sha(name,source=nil)
				$ScriptSHAMap[name] ||= (script_sha_from_key(name) || store_script(name,source))
			end
			
			def script_sha_from_key(name)
				(@tmp_store || store).get(script_sha_key(name))
			end
			
			class SourceNotFoundError < RuntimeError
				def initialize
					super("Could not locate script source")
				end
			end
			
			def store_script(name,source=nil)
				source ||= script_source_from_const(name)
				raise SourceNotFoundError unless source
				sha = (@tmp_store || store).script(:load,source)
				(@tmp_store || store).set(script_sha_key(name),sha)
				sha
			end
			
			def untrack_script(name)
				$ScriptSHAMap.delete name
				(@tmp_store || store).del(script_sha_key(name))
			end
			
			def script_source_from_const(name)
				(self.const_defined?(name.to_sym) && self.const_get(name.to_sym)) || (RedisObject::ScriptSources.const_defined?(name.to_sym) && RedisObject::ScriptSources.const_get(name.to_sym)) || nil
			end
			
			SCRIPT_KEY_PREFIX = "ScriptCache::SHA::".freeze
			
			def expire_all_script_shas(store_name=nil)
				store_obj = store_name.is_a?(String) || store_name.is_a?(Symbol) ? store(store_name.to_sym) : store_name
				store_obj.keys(script_sha_key("*")).each do |k|
					store_obj.del k
				end
				$ScriptSHAMap = {}
			end
			
			def script_sha_key(name)
				"#{SCRIPT_KEY_PREFIX}#{name.to_s}"
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
	
end