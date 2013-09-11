source "http://rubygems.org"

group :test do
	gem 'rake'
	gem 'rspec'
	gem 'coveralls', require: false
	gem 'fuubar'
	gem "codeclimate-test-reporter", require: nil
end

group :development, :test do
  gem 'guard-rspec'
end

# Specify your gem's dependencies in redis_object.gemspec
gemspec
