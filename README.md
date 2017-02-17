# Redis::Helper

Redisを扱うクラスで利用するモジュール

Redis::Objectsがmulti使えないとかアレっていう [@i2bskn](https://github.com/i2bskn) さん等の想いのカケラ。

## Installation

Add this line to your application's Gemfile:

```ruby
gem "redis-helper"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redis-helper

## Usage

```ruby
class Foo < ActiveRecord::Base
  include Redis::Helper
  define_attr_keys :bar_count

  def bar_count
    # bar_count_key == attr_key(:bar_count) == "Foo:<id>:bar_count"
    redis.get(bar_count_key).to_i
  end

  def update_bar_count(count)
    # ttl_to(self.end_at) => self.end_at - Time.current
    redis.setex(bar_count_key, ttl_to(self.end_at), count)
  end
end

foo = Foo.find(id)
foo.update_bar_count(10)
foo.bar_count => 10
```

## Contributing

1. Fork it ( https://github.com/Narazaka/redis-helper/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
