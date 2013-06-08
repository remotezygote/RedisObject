module Seabright
	module Views
		
		ViewFieldGetter = "local out = {}
			local key
			local val
			for i=1,#ARGV do
				key = ARGV[i]
				val = redis.call('HGET',KEYS[1],key)
				if val then
					table.insert(out,key)
					table.insert(out,val)
				end
			end
			return out".gsub(/\t/,'').freeze
		
		def view_as_hash(name)
			out = {}
			if requested_set = self.class.named_views[name]
				if requested_set.is_a?(Symbol) and self.respond_to?(requested_set)
					out = send(requested_set)
				else
					methods = requested_set[:fields].select {|f| self.respond_to?(f.to_sym) }
					if methods.count > 0
						methods.each do |m|
							out[m.to_s] = send(m.to_sym)
						end
					end
					if requested_set[:fields] && (flds = requested_set[:fields].select {|f| !out.keys.include?(f.to_s) }.map {|f| f.to_s }) && flds.count > 0
						res = Hash[*store.eval(ViewFieldGetter, [hkey], flds)]
						out.merge!(res)
					end
					if requested_set[:procs]
						requested_set[:procs].each do |k,proc|
							out[k.to_s] = proc.call(self)
						end
					end
					if requested_set[:hashes]
						requested_set[:hashes].each do |k,v|
							case v
							when String, Symbol
								out[k.to_s] = get(v)
							end
						end
					end
				end
			end
			out
		end
		
		def view_as_json(name)
			Yajl::Encoder.encode(view_as_hash(name))
		end
		
		module ClassMethods
			
			def named_view(name,*fields)
				named_views[name] = normalize_field_options(fields)
			end
			
			def named_views
				@named_views ||= {}
			end
			
			def normalize_field_options(fields)
				fields.flatten!
				fields.uniq!

				options = {}
				if fields.last.is_a?(Hash) # assume an option hash
					options.merge!(fields.slice!(fields.size - 1, 1)[0])
				end

				# assign a the method as a symbol to be exclusively invoked on view
				# so instead of returning a hash on view, it will return only what was
				# produced by calling the method.
				if options.keys.size > 0 and options[:method]
					out = options[:method].to_sym
				else
					hash = fields.select {|f| f.is_a?(Hash) }.inject({},:merge)
					out = {}
					if (h = hash.select {|k,v| !v.is_a?(Proc) }) && h.count > 0
						out[:hashes] = h
					end
					if (h = hash.select {|k,v| v.is_a?(Proc) }) && h.count > 0
						out[:procs] = h
					end
					if (h = fields.select {|o| o.is_a?(String) || o.is_a?(Symbol) }) && h.count > 0
						out[:fields] = h
					end
				end
				out
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end
