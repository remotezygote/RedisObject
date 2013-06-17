module Seabright
	module Types
		
		def self.alias_type(als,sym)
			type_aliases[als.to_s.downcase.to_sym] = sym.to_s.downcase.to_sym
		end
		
		def self.type_aliases
			@type_aliases ||= {}
		end
		
		def enforce_format(k,v)
			if v && (fmt = self.class.field_formats[k.to_sym]) && (sym = "format_#{fmt}".to_sym) && respond_to?(sym)
				send(sym,v)
			else 
				v
			end
		end
		
		def score_format(k,v)
			if v && (fmt = self.class.field_formats[k.to_sym]) && (sym = "score_#{fmt}".to_sym) && respond_to?(sym)
				send(sym,v)
			else 
				0
			end
		end
		
		def save_format(k,v)
			if v && (fmt = self.class.field_formats[k.to_s.gsub(/\=$/,'').to_sym]) && (sym = "save_#{fmt}".to_sym) && respond_to?(sym)
				send(sym,v)
			else 
				v
			end
		end
		
		module ClassMethods
			
			def method_missing(sym,*args,&block)
				if als = Seabright::Types.type_aliases[sym]
					org = sym
					sym = als
				end
				if known_types.include?(sym)
					register_type(sym,org)
					send(sym,*args,&block)
				else
					super(sym,*args,&block)
				end
			end
			
			def register_type(sym,als=nil)
				sym = sym.to_sym
				unless self.respond_to?(sym)
					require "redis_object/types/#{sym}" unless Seabright::Types.const_defined?("#{sym.to_s.capitalize}Type".to_sym)
					include Seabright::Types.const_get("#{sym.to_s.capitalize}Type".to_sym)
					metaclass = class << self; self; end
					metaclass.class_eval do
						define_method(sym) do |k|
							set_field_format k, sym
						end
						if als
							als = als.to_sym
							define_method(als) do |k|
								set_field_format k, sym
							end
						end
					end
					return true
				end
			end
			
			def known_types
				@known_types ||= [:array,:boolean,:date,:float,:json,:number]
			end
			
			def field_formats
				@field_formats_hash ||= (defined?(superclass.field_formats) ? superclass.field_formats.clone : {})
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
# require "redis_object/types/array"
require "redis_object/types/boolean"
# require "redis_object/types/date"
# require "redis_object/types/float"
# require "redis_object/types/json"
require "redis_object/types/number"
