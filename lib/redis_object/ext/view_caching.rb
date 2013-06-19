# View Caching
# 
# Cache a named view:
#   cache_named_view :admin_view
# 
# Invalidate all cached views when the I receive notification that something I reference or have been referenced by has changed:
#   invalidate_caches_from_upstream_updates!
# 
# Notify some objects that reference me when I am updated: (objects of these classes)
#   invalidate_upstream Property, Application, PaymentRequest, PaymentResponse
# 
# Notify some objects in my collections when I am updated: (objects in these collections)
#   invalidate_downstream :properties, :applications, :payment_requests, :payment_responses
# 
# You can also set up hooks for when this object is updated by certain types of objects by defining the following:
#   def invalidated_by(obj,chain)
#     invalidate_cached_view :blah
#   end
#   
#   def invalidated_by_user(obj,chain)
#     invalidate_cached_view :users
#   end
#   

module Seabright
	module ViewCaching
		
		CachedViewInvalidator = "
			for i=1,#ARGV do
				redis.call('HDEL', KEYS[1], ARGV[i])
			end".gsub(/\t/,'').freeze
				
		module ClassMethods
			
			def cache_view(name,opts=true)
				cached_views[name.to_sym] = opts
			end
			alias_method :cache_named_view, :cache_view
			
			def intercept_views_for_caching!
				return if @cached_views_intercepted
				self.class_eval do
					
					alias_method :uncached_view_as_hash, :view_as_hash unless method_defined?(:uncached_view_as_hash)
					def view_as_hash(name)
						return uncached_view_as_hash(name) unless self.class.view_should_be_cached?(name)
						if v = view_from_cache(name)
							puts "  Got view from cache: #{name}" if DEBUG
							Yajl::Parser.parse(v)
						else
							puts "  View cache miss: #{name}" if DEBUG
							cache_view_content(name)[0]
						end
					end
					
					alias_method :uncached_view_as_json, :view_as_json unless method_defined?(:uncached_view_as_json)
					def view_as_json(name)
						return uncached_view_as_json(name) unless self.class.view_should_be_cached?(name)
						if v = view_from_cache(name)
							puts "  Got view from cache: #{name}" if DEBUG
							v
						else
							puts "  View cache miss: #{name}" if DEBUG
							cache_view_content(name)[1]
						end
					end
					
					def cache_view_content(name,content=nil)
						content ||= uncached_view_as_hash(name)
						json = Yajl::Encoder.encode(content)
						store.hset(cached_view_key,name,json)
						[content,json]
					end
					
					def view_from_cache(name)
						if v = store.hget(cached_view_key,name)
							v
						else
							nil
						end
					end
					
					def view_is_cached?(name)
						store.hexists(cached_view_key, name)
					end
					
					def cached_view_key
						"#{hkey}::ViewCache"
					end
					
					def regenerate_cached_views(*names)
						names.each do |name|
							cache_view_content name
						end
					end
					
					def regenerate_cached_views!
						regenerate_cached_views(*self.class.cached_views.map {|name,opts| name })
					end
					
				end
				@cached_views_intercepted = true
			end
			
			def set_up_invalidation!
				return if @invalidation_set_up
				self.class_eval do
					
					def invalidate_cached_views(*names)
						puts "Invalidating cached views: #{names.join(", ")}" if Debug.verbose?
						run_script(:CachedViewInvalidator, [cached_view_key], names, CachedViewInvalidator)
						self.class.cache_invalidation_hooks do |hook|
							hook.call(names)
						end
					end
					alias_method :invalidate_cached_view, :invalidate_cached_views
					
					def invalidate_cached_views!
						invalidate_cached_views(*self.class.cached_views.map {|name,opts| name })
					end
					
					def invalidate_downstream!
						return unless self.class.downstream_invalidations && (self.class.downstream_invalidations.size > 0)
						puts "Invalidating downstream: #{self.class.downstream_invalidations.inspect}" if Debug.verbose?
						self.class.downstream_invalidations.each do |col|
							if has_collection?(col) && (colctn = get_collection(col))
								colctn.each do |obj|
									obj.invalidated_by_other(self,invalidation_chain + [self.hkey])
								end
							end
						end
					end
					
					def invalidate_upstream!
						return unless self.class.upstream_invalidations && (self.class.upstream_invalidations.size > 0)
						puts "Invalidating upstream: #{self.class.upstream_invalidations.inspect}" if Debug.verbose?
						backreferences.each do |obj|
							next unless self.class.upstream_invalidations.include?(obj.class.name.split("::").last.to_sym) #|| self.class.invalidate_everything_upstream?
							obj.invalidated_by_other(self,invalidation_chain + [self.hkey]) if obj.respond_to?(:invalidated_by_other)
						end
					end
					
					def invalidated_by_update!(*args)
						Thread.new do
							invalidate_cached_views!
							invalidate_up_and_down!
						end
					end
					
					def invalidated_by_reference!(*args)
						invalidated_by_update!
					end
					
					def invalidation_chain
						@invalidation_chain ||= []
					end
					
					def invalidate_up_and_down!
						unless invalidation_chain.include?(self)
							invalidate_downstream!
							invalidate_upstream!
						end
					end
					
					def invalidated_by_other(obj,chain)
						unless chain.include?(self.hkey)
							puts "#{self.class.name}:#{self.id}'s view caches were invalidated by upstream object: #{obj.class.name}:#{obj.id} (chain:#{chain.inspect})" if Debug.verbose?
							@invalidation_chain = chain
							[:invalidated_by,"invalidated_by_#{obj.class.name.underscore}".to_sym].each do |meth_sym|
								send(meth_sym,obj,chain) if respond_to?(meth_sym)
							end
							invalidate_up_and_down!
						end
					end
					
					def invalidated_by(obj,chain)
						invalidate_cached_views!
					end
					
					def invalidated_set(cmd,k,v)
						ret = send("uninvalidated_#{cmd}".to_sym,k,v)
						invalidated_by_update!
						ret
					end
					
					alias_method :uninvalidated_set, :set unless method_defined?(:uninvalidated_set)
					def set(k,v)
						invalidated_set(:set,k,v)
					end
					
					alias_method :uninvalidated_setnx, :setnx unless method_defined?(:uninvalidated_setnx)
					def setnx(k,v)
						invalidated_set(:setnx,k,v)
					end
					
					# trigger_on_update :invalidated_by_update!
					trigger_on_reference :invalidated_by_reference!
					
				end
				@invalidation_set_up = true
			end
			
			def invalidate_caches_from_upstream_updates!
				self.class_eval do
					
					def invalidated_by(obj,chain)
						invalidate_cached_views!
					end
					
				end
			end
			
			def on_cache_invalidation(&block)
				cache_invalidation_hooks << block
			end
			
			def cache_invalidation_hooks
				@cache_invalidation_hooks ||= []
			end
			
			def invalidate_upstream(*args)
				@upstream_invalidations = (@upstream_invalidations || []) + args
			end
			
			def upstream_invalidations
				@upstream_invalidations ||= []
			end
			
			# def invalidate_everything_upstream!
			# 	@invalidate_everything_upstream = true
			# end
			# 
			# def invalidate_everything_upstream?
			# 	@invalidate_everything_upstream
			# end
			
			def invalidate_downstream(*args)
				@downstream_invalidations = (@downstream_invalidations || []) + args
			end
			
			def downstream_invalidations
				@downstream_invalidations ||= []
			end
			
			# def invalidate_everything_downstream!
			# 	@invalidate_everything_downstream = true
			# end
			# 
			# def invalidate_everything_downstream?
			# 	@invalidate_everything_downstream
			# end
			
			def view_should_be_cached?(name)
				!!cached_views[name.to_sym]
			end
			
			def cached_views
				@cached_view ||= {}
			end
			
			def cache_named_views!
				named_views.each do |name,view|
					cache_view name
				end
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
			base.intercept_views_for_caching!
			base.set_up_invalidation!
		end
		
	end
end