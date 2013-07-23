class ListEnumerator < Enumerator
	
	def initialize(base,&block)
		@base = base
		super(&block)
	end
	
	def count
		@base.size
	end
	
	def member?(obj)
		case obj
		when String
			@base.member?(obj)
		else
			super(obj)
		end
	end
	
end