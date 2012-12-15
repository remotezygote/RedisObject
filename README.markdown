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

The minimum config file looks something like this:

```ruby
    Bluepill.application("app_name") do |app|
      app.process("process_name") do |process|
        process.start_command = "/usr/bin/some_start_command"
        process.pid_file = "/tmp/some_pid_file.pid"
      end
    end
```

## Links
Redis: [http://redis.io](http://redis.io)  
RedisObject Code: [https://github.com/remotezygote/RedisObject](https://github.com/remotezygote/RedisObject)  


[rubygems]: http://rubygems.org/gems/redis_object