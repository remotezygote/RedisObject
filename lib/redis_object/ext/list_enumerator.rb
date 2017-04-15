class ListEnumerator < Enumerator
	
	def initialize(base,&block)
		@base = base
		super(&block)
	end
	
	def count
		@base.count
	end
	
	def member?(obj)
		case obj
		when String
			@base.member?(obj)
		else
			super(obj)
		end
	end
	
	def +(other)
		ListEnumerator.new([]) do |y|
			each { |e| y << e }
			other.each { |e| y << e }
		end
	end

end
