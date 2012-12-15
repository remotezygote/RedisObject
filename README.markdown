# RedisObject
RedisObject is a fast and simple-to-use object persistence layer for Ruby.

## Prerequisites
You'll need [Redis](http://redis.io).


## Installation
It&apos;s hosted on [rubygems.org][rubygems].

    sudo gem install redis_object


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
    RedisObject.configure_store({})
```

Or, you can configure multiple stores to use within an app by passing a second parameter to name the store (default is 'general')

```ruby
    RedisObject.configure_store({}, :message_queue)
    
    class Message < RedisObject
      use_store :message_queue
    end
```

## 'Collections'
Object relationships are stored in collections of objects attached to other objects. To 'collect' and object onto another, you simply call `reference` to reference the objects (also aliased to the concat operator `<<`).

Collections are automatically created, and can be access by their plural, lower-case name to gather all of the items in a collection (returns and Enumerable `Collection` object), or by its singular lower-case name to just get one somewhat randomly (useful for 1 -> 1 style relationships).

Example:

```ruby
    class Person < RedisObject; end
    class Address < RedisObject; end
    john = Person.create("john")
    john << Address.create({:street => "123 Main St.", :city => "San Francisco", :state => "CA", :zip => "12345"})

    john.addresses # ["Address:john"]
    john.address # {:address_id => "john", :street => "123 Main St.", :city => "San Francisco", :state => "CA", :zip => "12345", :class=>"Address", :key=>"Address:john", :created_at=>Wed, 12 Dec 2012 16:49:26 -0800, :updated_at=>Wed, 12 Dec 2012 16:49:26 -0800}
```

You may also notice that the type of object, its basic storage key, and some timestamps are also automatically created and updated appropriately.

It is important to note that collections inherit any indices of its underlying object type. See Indices below for examples.

## Types
A few types of data can be specified for certain fields. The types supported are:

Date
Number
Float
Bool
Array
JSON (store any data that can be JSON-encoded - it will be automatically encoded/decoded when stored/accessed)

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

TODO: Add verified? and verified! methods automagically for boolean fields.

## Indices


## Links
Redis: [http://redis.io](http://redis.io)  
RedisObject Code: [https://github.com/remotezygote/RedisObject](https://github.com/remotezygote/RedisObject)  


[rubygems]: http://rubygems.org/gems/redis_object