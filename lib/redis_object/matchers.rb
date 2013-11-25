module Seabright
	module Matchers
		
		module ClassMethods
			
			NilPattern = 'nilpattern:'
			
			GetKeyList = "local itms
				if KEYS[2] then
					itms = {}
					for n=2,#KEYS do
						local kys = redis.call('SMEMBERS',KEYS[n])
						for k=1,#kys do
							local rk
							if kys[k]:match('.*_h') then
								rk = kys[k]
							else
								rk = kys[k]..'_h'
							end
							table.insert(itms, rk)
						end
					end
				else
					itms = {}
					local kys = redis.call('SMEMBERS',KEYS[1])
					for k=1,#kys do
						local rk
						if kys[k]:match('.*_h') then
							rk = kys[k]
						else
							rk = kys[k]..'_h'
						end
						table.insert(itms, rk)
					end
				end".gsub(/\t/,'').freeze
			
			RedisObject::ScriptSources::KeyListFor = GetKeyList + "
				return itms
			".gsub(/\t/,'').freeze
			
			RedisObject::ScriptSources::Matcher = GetKeyList + "
				local out = {}
				local val
				local pattern
				for i, v in ipairs(itms) do
					val = redis.call('HGET',v,ARGV[1])
					if val then
						if ARGV[2]:find('^pattern:') then
							pattern = ARGV[2]:gsub('^pattern:','')
							if val:match(pattern) then
								table.insert(out,itms[i])
							end
						elseif ARGV[2]:find('^ipattern:') then
							pattern = ARGV[2]:gsub('^ipattern:',''):lower()
							if val:lower():match(pattern) then
								table.insert(out,itms[i])
							end
						else
							if val == ARGV[2] then
								table.insert(out,itms[i])
							end
						end
					else
						if ARGV[2] == '#{NilPattern}' then
							table.insert(out,itms[i])
						end
					end
				end
				return out".gsub(/\t/,'').freeze
			
			RedisObject::ScriptSources::MultiMatcher = GetKeyList + "
				local out = {}
				local matchers = {}
				local matcher = {}
				local mod
				for i=1,#ARGV do
					mod = i % 2
					if mod == 1 then
						matcher[1] = ARGV[i]
					else
						matcher[2] = ARGV[i]
						table.insert(matchers,matcher)
						matcher = {}
					end
				end
				local val
				local good
				local pattern
				for i, v in ipairs(itms) do
					good = true
					for n=1,#matchers do
						val = redis.call('HGET',v,matchers[n][1])
						if val then
							if matchers[n][2]:find('^pattern:') then
								pattern = matchers[n][2]:gsub('^pattern:','')
								if val:match(pattern) then
									good = good
								else
									good = false
									break
								end
							elseif matchers[n][2]:find('^ipattern:') then
								pattern = matchers[n][2]:gsub('^ipattern:',''):lower()
								if val:lower():match(pattern) then
									good = good
								else
									good = false
									break
								end
							else
								if val ~= matchers[n][2] then
									good = false
									break
								end
							end
						else
							if matchers[n][2] == '#{NilPattern}' then
								good = good
							else
								good = false
								break
							end
						end
					end
					if good == true then
						table.insert(out,itms[i])
					end
				end
				return out".gsub(/\t/,'').freeze
			
			RedisObject::ScriptSources::OrMatcher = GetKeyList + "
				local out = {}
				local matchers = {}
				local matcher = {}
				local mod
				for i=1,#ARGV do
					mod = i % 2
					if mod == 1 then
						matcher[1] = ARGV[i]
					else
						matcher[2] = ARGV[i]
						table.insert(matchers,matcher)
						matcher = {}
					end
				end
				
				local val
				local good
				local pattern
				for i, v in ipairs(itms) do
					good = false
					for n=1,#matchers do
						val = redis.call('HGET',v,matchers[n][1])
						if val then
							if matchers[n][2]:find('^pattern:') then
								pattern = matchers[n][2]:gsub('^pattern:','')
								if val:match(pattern) then
									good = true
									break
								else
									good = good
								end
							elseif matchers[n][2]:find('^ipattern:') then
								pattern = matchers[n][2]:gsub('^ipattern:',''):lower()
								if val:lower():match(pattern) then
									good = true
									break
								else
									good = good
								end
							else
								if val == matchers[n][2] then
									good = true
									break
								end
							end
						else
							if matchers[n][2] == '#{NilPattern}' then
								good = good
								break
							else
								good = false
							end
						end
					end
					if good == true then
						table.insert(out,itms[i])
					end
				end
				return out".gsub(/\t/,'').freeze
			
			def match(pkt, use_or=false)
				if use_or
					mtchr = :OrMatcher
				else
					mtchr = pkt.keys.count > 1 ? :MultiMatcher : :Matcher
				end
				if (ids = pkt[id_sym] || pkt[id_sym.to_s]) and !ids.is_a?(Regexp)
					return match_by_id(ids, pkt, use_or)
				end
				indcs = [plname] + extract_usable_indices(pkt)
				pkt = pkt.flatten.reduce([]) do |i,v|
					x = case v
					when Regexp
						convert_regex_to_lua(v)
					when Array
						raise ArgumentError.new("An array can only be used with the find_or method") unless use_or
						inject_key(i.last, v)
					when NilClass
						NilPattern
					else
						v.to_s
					end
					i << x
					i
				end
				kys = run_script(mtchr, indcs, pkt.flatten)
				ListEnumerator.new(kys) do |y|
					kys.each do |k|
						y << find(k)
					end
				end
			end
			
			RedisObject::ScriptSources::FirstMatcher = GetKeyList + "
				local val
				local pattern
				for i, v in ipairs(itms) do
					val = redis.call('HGET',v,ARGV[1])
					if val then
						if ARGV[2]:find('^pattern:') then
							pattern = ARGV[2]:gsub('^pattern:','')
							if val:match(pattern) then
								return itms[i]
							end
						elseif ARGV[2]:find('^ipattern:') then
							pattern = ARGV[2]:gsub('^ipattern:',''):lower()
							if val:lower():match(pattern) then
								return itms[i]
							end
						else
							if val == ARGV[2] then
								return itms[i]
							end
						end
					else
						if ARGV[2] == '#{NilPattern}' then
							return itms[i]
						end
					end
				end
				return ''".gsub(/\t/,'').freeze
			
			RedisObject::ScriptSources::FirstMultiMatcher = GetKeyList + "
				local matchers = {}
				local matcher = {}
				local mod
				for i=1,#ARGV do
					mod = i % 2
					if mod == 1 then
						matcher[1] = ARGV[i]
					else
						matcher[2] = ARGV[i]
						table.insert(matchers,matcher)
						matcher = {}
					end
				end
				local val
				local good
				local pattern
				for i, v in ipairs(itms) do
					good = true
					for n=1,#matchers do
						val = redis.call('HGET',v,matchers[n][1])
						if val then
							if matchers[n][2]:find('^pattern:') then
								pattern = matchers[n][2]:gsub('^pattern:','')
								if val:match(pattern) then
									good = good
								else
									good = false
									break
								end
							elseif matchers[n][2]:find('^ipattern:') then
								pattern = matchers[n][2]:gsub('^ipattern:',''):lower()
								if val:lower():match(pattern) then
									good = good
								else
									good = false
									break
								end
							else
								if val ~= matchers[n][2] then
									good = false
									break
								end
							end
						else
							if matchers[n][2] == '#{NilPattern}' then
								good = good
							else
								good = false
								break
							end
						end
					end
					if good == true then
						return itms[i]
					end
				end
				return ''".gsub(/\t/,'').freeze
			
			RedisObject::ScriptSources::FirstOrMatcher = GetKeyList + "
				local matchers = {}
				local matcher = {}
				local mod
				for i=1,#ARGV do
					mod = i % 2
					if mod == 1 then
						matcher[1] = ARGV[i]
					else
						matcher[2] = ARGV[i]
						table.insert(matchers,matcher)
						matcher = {}
					end
				end
				
				local val
				local good
				local pattern
				for i, v in ipairs(itms) do
					good = false
					for n=1,#matchers do
						val = redis.call('HGET',v,matchers[n][1])
						if val then
							if matchers[n][2]:find('^pattern:') then
								pattern = matchers[n][2]:gsub('^pattern:','')
								if val:match(pattern) then
									good = true
									break
								else
									good = good
								end
							elseif matchers[n][2]:find('^ipattern:') then
								pattern = matchers[n][2]:gsub('^ipattern:',''):lower()
								if val:lower():match(pattern) then
									good = true
									break
								else
									good = good
								end
							else
								if val == matchers[n][2] then
									good = true
									break
								end
							end
						else
							if matchers[n][2] == '#{NilPattern}' then
								good = good
								break
							else
								good = false
							end
						end
					end
					if good == true then
						return itms[i]
					end
				end
				return ''".gsub(/\t/,'').freeze
			
			def extract_usable_indices(pkt)
				pkt.inject([]) do |acc,(k,v)|
					if self.has_index?(k)
						acc << index_key(k,v)
					end
					acc
				end
			end
			
			def match_by_id(ids, pkt, use_or = false)
				case ids
				when Array
					raise ArgumentError.new("An array can only be used with the or_find_first method") unless use_or
					ids.map do |i|
						match_by_id(i, pkt, use_or)
					end.flatten
				when String, Symbol
					if obj = find(ids)
						pkt.each do |k,v|
							case v
							when Regexp
								return nil unless v.match(obj.get(k))
							when Array
								raise ArgumentError.new("An array can only be used with the or_find_first method") unless use_or
								return nil unless v.any? { |val| obj.get(k) == v }
							when String, Symbol
								return nil unless obj.get(k) == v
							when NilClass
								return nil unless obj.get(k) == nil
							end
						end
					end
					[obj]
				end
			end
			
			def match_first(pkt, use_or=false)
				if use_or
					mtchr = :FirstOrMatcher
				else
					mtchr = pkt.keys.count > 1 ? :FirstMultiMatcher : :FirstMatcher
				end
				if (ids = pkt[id_sym] || pkt[id_sym.to_s]) and !ids.is_a?(Regexp)
					return match_by_id(ids, pkt, use_or).first
				end
				indcs = [plname] + extract_usable_indices(pkt)
				pkt = pkt.flatten.reduce([]) do |i,v|
					x = case v
					when Regexp
						convert_regex_to_lua(v)
					when Array
						raise ArgumentError.new("An array can only be used with the or_find_first method") unless use_or
						inject_key(i.last, v)
					when NilClass
						NilPattern
					else
						v.to_s
					end
					i << x
					i
				end
				find_by_key(run_script(mtchr,indcs, pkt.flatten))
			end
			
			def inject_key(key,list)
				out = []
				list.each do |i|
					if i == list.first
						out << i
					else
						out << key
						out << i
					end
				end
				out
			end
			
			def convert_regex_to_lua(reg)
				"#{reg.casefold? ? "i" : ""}pattern:#{reg.source.gsub("\\","")}"
			end
			
			def grab(ident)
				case ident
				when String, Symbol
					return store.exists(self.hkey(ident.to_s)) ? self.new(ident.to_s) : nil
				when Hash
					return match(ident)
				end
				nil
			end
			
			def or_grab(ident)
				case ident
				when Hash
					return match(ident, true)
				end
				nil
			end
			
			def find(ident)
				grab(ident)
			end
			
			def find_first(ident)
				match_first(ident)
			end
			
			def or_find(ident)
				or_grab(ident)
			end
			
			def or_find_first(ident)
				match_first(ident)
			end
			
		end
		
		def self.included(base)
			base.extend(ClassMethods)
		end
		
	end
end

