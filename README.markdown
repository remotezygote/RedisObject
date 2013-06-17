# RedisObject
RedisObject is a fast and simple-to-use object persistence layer for Ruby.

[![Build Status](https://travis-ci.org/remotezygote/RedisObject.png?branch=master)](https://travis-ci.org/remotezygote/RedisObject)
[![Coverage Status](https://coveralls.io/repos/remotezygote/RedisObject/badge.png?branch=master)](https://coveralls.io/r/remotezygote/RedisObject?branch=master)
[![Code Climate](https://codeclimate.com/github/remotezygote/RedisObject.png)](https://codeclimate.com/github/remotezygote/RedisObject)

## Prerequisites
You'll need [Redis](http://redis.io). Other storage adapters are in the works. Maybe.


## Installation

	gem install redis_object

Or, you can add it to your Gemfile:

	gem 'redis_object'


## Usage
###  Simple Example
```ruby
class Thing < RedisObject
  def name
    "#{first_name} #{last_name}"
  end
  def name=(new_name)
    first, last = new_name.split(" ")
    set(:first_name,first)
    set(:last_name,last)
  end
end
a = Thing.create("an_id")
a.name = "Testy Testerton"
b = Thing.create({:first_name => "Testy", :last_name => "Testerton"})
```

### Config
You can configure the storage adapter by sending a packet of commands to `configure_store` like:

```ruby
RedisObject.configure_store({:db: 2})
```

The default storage adapter is `Redis`. The above config will connect to Redis on localhost on the default port (6379), but will `select` database number 2.

Or, you can configure multiple stores to use within an app by passing a second parameter to name the store (default is 'general')

```ruby
RedisObject.configure_store({adapter: "Redis", :db: 4, :path: "/var/run/redis.sock"}, :message_queue)

class Message < RedisObject
  use_store :message_queue
end
```

## 'Collections'
Object relationships are stored in collections of objects attached to other objects. To 'collect' an object onto another, you simply call `reference` to reference the objects (also aliased to the concat operator `<<`).

Collections are automatically created, and can be access by their plural, lower-case name to gather all of the items in a collection (returns an Enumerable `Collection` object), or by its singular lower-case name to just get one somewhat randomly (useful for 1 -> 1 style relationships).

Example:

```ruby
class Person < RedisObject; end
class Address < RedisObject; end
john = Person.create("john")
john << Address.create({
  :street => "123 Main St.",
  :city => "San Francisco",
  :state => "CA",
  :zip => "12345"
})

john.addresses
# ["Address:john"]
john.address 
# {
#   :address_id => "john",
#   :street => "123 Main St.",
#   :city => "San Francisco",
#   :state => "CA",
#   :zip => "12345",
#   :class=>"Address",
#   :key=>"Address:john",
#   :created_at=>Wed, 12 Dec 2012 16:49:26 -0800,
#   :updated_at=>Wed, 12 Dec 2012 16:49:26 -0800
# }
```

You may notice that the type of object, its basic storage key, and some timestamps are automatically created and updated appropriately.

It is important to note that collections inherit any indices of its underlying object type. See Indices below for examples.

## Types
A few types of data can be specified for certain fields. The types supported are:

* Date
* Number
* Float
* Bool
* Array
* JSON (store any data that can be JSON-encoded - it will be automatically encoded/decoded when stored/accessed)

These types are also used for scoring when keeping field indices. If no type is specified, String is used, and no scoring is possible at this time.

Setting the type of a field is super easy:

```ruby
class Person < RedisObject
  bool :verified
  json :meta
end

john = Person.create("john")
john.meta = {:external_id => "123456", :number => 123}
john.verified # false
```

TODO: Add verified? and verified! -style methods automagically for boolean fields.

You can add your own custom types by defining filter methods for getting and setting a field, and can define a scoring function if you would like to index fields of your type.

Example:

```ruby
class Person < RedisObject

  def format_boolean(val)
    val=="true"
  end

  def save_boolean(val)
    val ? "true" : "false"
  end

  def score_boolean(val)
    val ? 1 : 0
  end

  class << self
    def bool(k)
      field_formats[k] = :format_boolean
      save_formats[k] = :save_boolean
      score_formats[k] = :score_boolean
    end
    alias_method :boolean, :bool

  end

end
```

TODO: Make defining custom formats easier - no need to define class methods for this - could have helper function for it like `custom_format :bool, :get => :format_boolean` or similar.

## Indices
Any field that can be scored can store a sidecar index by that score. These indices can be used to index items in a collection (internally, it is a simple Redis set intersection, so it is very fast). Timestamps are indexed by default for any object, so out of the box you can do:

```ruby
Person.indexed(:created_at) # all Person objects, oldest first
Person.indexed(:created_at, 1, true) # newest Person (index_field, number of items, reverse sort?)
Person.latest # always available if timestamps are on - most recently created object of type
john.addresses.indexed(:created_at, 3, true) # john's 3 most recent addresses
Person.indexed(:updated_at, -1, true) do |person|
  # iterate through Person objects in order of update times, most recent first
end
```

Accessing indexed items always returns an Enumerator, so first/last/each/count/etc. are usable anywhere and will access objects only when iterated.

## Named Views
`TODO: Add some damn View documentation.`

## Links
Redis: [http://redis.io](http://redis.io)  
RedisObject Code: [https://github.com/remotezygote/RedisObject](https://github.com/remotezygote/RedisObject)  


[rubygems]: http://rubygems.org/gems/redis_object
