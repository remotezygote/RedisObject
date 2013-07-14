require 'logger'

module Seabright
	class Log
		
		class << self
			
			def verbose(*args)
				logger.verbose(*args) if logger.respond_to?(:verbose)
			end
			
			def debug(*args)
				logger.debug(*args)
			end
			
			def info(*args)
				logger.info(*args)
			end
			
			def warn(*args)
				logger.warn(*args)
			end
			
			def error(*args)
				logger.error(*args)
			end
			
			def fatal(*args)
				logger.fatal(*args)
			end
			
			def logger
				@@logger ||= Proc.new do
					lg = Logger.new(STDOUT)
					lg.level = Logger::WARN
					lg
				end.call
			end
			
			def logger=(new_logger)
				@@logger = new_logger
			end
			
		end
		
	end
end