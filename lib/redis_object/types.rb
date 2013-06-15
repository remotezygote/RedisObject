module Seabright
	module Types
		
		def enforce_format(k,v)
			if v && fmt = self.class.field_formats[k.to_sym] 
				send(fmt,v)
			else 
				v
			end
		end
		
		def score_format(k,v)
			if v && fmt = self.class.score_formats[k.to_sym] 
				send(fmt,v)
			else 
				0
			end
		end
		
		def save_format(k,v)
			v && (fmt = self.class.save_formats[k.to_s.gsub(/\=$/,'').to_sym]) ? send(fmt,v) : v
		end
		
		def format_date(val)
			begin
				val.instance_of?(DateTime) ? val : ( val.instance_of?(String) ? DateTime.parse(val) : nil )
			rescue StandardError => e
				puts "Could not parse value as date using Date.parse. Returning nil instead. Value: #{val.inspect}\nError: #{e.inspect}" if DEBUG
				nil
			end
		end
		
		def score_date(val)
			val.to_time.to_i
		end
		
		def format_array(val)
			Yajl::Parser.new(:symbolize_keys => true).parse(val)
		end
		
		def format_number(val)
			val.to_i
		end
		
		def score_number(val)
			Float(val)
		end
		
		def format_float(val)
			Float(val)
		end
		alias_method :score_float, :format_float
		
		def format_json(val)
			return val if val.is_a?(String)
			Yajl::Parser.new(:symbolize_keys => true).parse(val)
		end
		
		def save_json(val)
			Yajl::Encoder.encode(val)
		end
		
		def save_array(val)
			Yajl::Encoder.encode(val)
		end
		
		def format_boolean(val)
			val=="true"
		end
		
		def score_boolean(val)
			val ? 1 : 0
		end
		
		module ClassMethods
			
			def date(k)
				set_field_format(k, :format_date)
				set_score_format(k, :score_date)
			end
			
			def number(k)
				set_field_format(k, :format_number)
				set_score_format(k, :score_number)
			end
			alias_method :int, :number
			
			def float(k)
				set_field_format(k, :format_float)
				set_score_format(k, :score_float)
			end
			
			def bool(k)
				set_field_format(k, :format_boolean)
				set_score_format(k, :score_boolean)
			end
			alias_method :boolean, :bool
			
			def array(k)
				set_field_format(k, :format_array)
				set_save_format(k, :save_array)
			end
			
			def json(k)
				set_field_format(k, :format_json)
				set_save_format(k, :save_json)
			end
			
			def field_formats
				@field_formats_hash ||= (defined?(superclass.field_formats) ? superclass.field_formats.clone : {})
			end
			
			def score_formats
				@score_formats_hash ||= (defined?(superclass.score_formats) ? superclass.score_formats.clone : {})
			end
			
			def save_formats
				@save_formats_hash ||= (defined?(superclass.save_formats) ? superclass.save_formats.clone : {})
			end
			
			def set_field_format(k, v)
				field_formats_set_locally.add(k)
				field_formats[k] = v
				update_child_class_field_formats(k, v)
				intercept_for_typing!
			end
			
			def field_formats_set_locally
				@field_formats_set_locally_set ||= Set.new
			end
			
			def inherit_field_format(k, v)
				unless fields_formats_set_locally.include? k
					field_formats[k] = v
					update_child_class_field_formats(k, v)
				end
				intercept_for_typing!
			end
			
			def update_child_class_field_formats(k, v)
				child_classes.each do |child_class|
					child_class.inherit_field_format(k, v)
				end
			end
			
			def set_score_format(k, v)
				score_formats_set_locally.add(k)
				score_formats[k] = v
				update_child_class_score_formats(k, v)
				intercept_for_typing!
			end
			
			def score_formats_set_locally
				@score_formats_set_locally_set ||= Set.new
			end
			
			def inherit_score_format(k, v)
				unless scores_formats_set_locally.include? k
					score_formats[k] = v
					update_child_class_score_formats(k, v)
				end
				intercept_for_typing!
			end
			
			def update_child_class_score_formats(k, v)
				child_classes.each do |child_class|
					child_class.inherit_score_format(k, v)
				end
			end
			
			def set_save_format(k, v)
				save_formats_set_locally.add(k)
				save_formats[k] = v
				update_child_class_save_formats(k, v)
				intercept_for_typing!
			end
			
			def save_formats_set_locally
				@save_formats_set_locally_set ||= Set.new
			end
			
			def inherit_save_format(k, v)
				unless save_formats_set_locally.include? k
					save_formats[k] = v
					update_child_class_save_formats(k, v)
				end
				intercept_for_typing!
			end
			
			def update_child_class_save_formats(k, v)
				child_classes.each do |child_class|
					child_class.inherit_save_format(k, v)
				end
			end
			
			def register_format(k,fmt)
				send(fmt, k)
			end
			
			def describe
				all_keys.inject({}) do |acc,(k,v)|
					if field_formats[k.to_sym]
						acc[k.to_sym] ||= [field_formats[k.to_sym].to_s.gsub(/^format_/,'').to_sym, 0]
					else
						acc[k.to_sym] ||= [:string, 0]
					end
					acc[k.to_sym][1] += 1
					acc
				end
			end
			
			def dump_schema(file)
				child_classes_set.sort {|a,b| a.name <=> b.name}.each do |child|
					file.puts "# #{child.name}"
					# sort fields by number of instances found
					child.describe.sort {|a,b| b[1][1] <=> a[1][1]}.each do |field,(type, count)|
						file.puts "#{field}: #{type} (#{count})"
					end
					file.puts
				end
			end
			
			def intercept_for_typing!
				return if @intercepted_for_typing
				self.class_eval do
					
					alias_method :untyped_get, :get unless method_defined?(:untyped_get)
					def get(k)
						enforce_format(k,untyped_get(k))
					end
					
					alias_method :untyped_mset, :mset unless method_defined?(:untyped_mset)
					def mset(dat)
						dat.merge!(dat) {|k,v1,v2| save_format(k,v1) }
						untyped_mset(dat)
					end
					
					alias_method :untyped_set, :set unless method_defined?(:untyped_set)
					def set(k,v)
						untyped_set(k,save_format(k,v))
					end
					
					alias_method :untyped_setnx, :setnx unless method_defined?(:untyped_setnx)
					def setnx(k,v)
						untyped_setnx(k,save_format(k,v))
					end
					
				end
				@intercepted_for_typing = true
			end
			
			private
			
			def all_keys(limit=100)
				steps = 0
				all.inject([]) do |acc,obj|
					store.hkeys(obj.hkey).each do |k|
						acc << k.to_sym
					end
					steps += 1
					return acc if steps >= limit
					acc
				end
			end
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end
