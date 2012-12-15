module Seabright
	module Benchmark
		
		module ClassMethods
			
			def benchmark(*method_names)
				method_names.each do |method_name|
					original_method = instance_method(method_name)
					define_method(method_name) do |*args,&blk|
						st = Time.now
						out = original_method.bind(self).call(*args,&blk)
						self.class.benchmark_out(method_name,args,Time.now - st)
						out
					end
				end
			end
			
			def benchmark_out(method,args,time)
				puts "[RedisObject::Benchmark] #{method}(#{args.join(",")}): #{time}"
			end
			
			def benchmark!
				benchmark :set, :get, :<<
			end
				
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
	
end