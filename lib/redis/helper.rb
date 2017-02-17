require "redis"
require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/numeric/time"
require "redis/helper/version"

# Redisを扱うクラスで利用するモジュール
#
# @example
#   class Foo < ActiveRecord::Base
#     include Redis::Helper
#     attr_key :bar_count
#
#     def bar_count
#       # bar_count_key == attr_key(:bar_count) == "Foo:<id>:bar_count"
#       redis.get(bar_count_key).to_i
#     end
#
#     def update_bar_count(count)
#       # ttl_to(self.end_at) => self.end_at - Time.current
#       redis.setex(bar_count_key, ttl_to(self.end_at), count)
#     end
#   end
#
#   foo = Foo.find(id)
#   foo.update_bar_count(10)
#   foo.bar_count => 10
#
class Redis
  module Helper
    # 正しくない固有キー(固有キー値が空?)
    class UnknownUniqueValue < StandardError; end

    # デフォルトの固有キー名
    DEFAULT_UNIQUE_ATTR_NAME = :id
    # redisキーの区切り文字
    REDIS_KEY_DELIMITER = ":".freeze

    def self.included(klass)
      klass.extend ClassMethods
    end

    # クラスメソッド
    module ClassMethods
      # Redis.currentへのショートカット
      def redis
        @redis ||= ::Redis.current
      end

      # 固定キーメソッドを作成する
      def attr_key(*basenames, unique_attr: nil)
        basenames.each do |basename|
          define_method(:"#{basename}_key") do
            attr_key(basename, unique_attr)
          end
        end
      end
    end

    # instance固有のkeyとattr_nameからkeyを生成する
    # (instanceに複数のkeyを設定したい場合やkeyにattr_nameを含めたい場合に使用する)
    # @param [String|Symbol] name キー名
    # @param [String|Symbol] unique_attr インスタンスの固有キーとして使用するメソッド名
    # @return [String]
    def attr_key(name, unique_attr = nil)
      [instance_key(unique_attr), name].join(REDIS_KEY_DELIMITER)
    end

    # instance固有のkeyを生成する ("<Class Name>:<unique key>")
    # @param [String|Symbol] unique_attr インスタンスの固有キーとして使用するメソッド名
    # @return [String]
    def instance_key(unique_attr = nil)
      attr_name = unique_attr || DEFAULT_UNIQUE_ATTR_NAME
      if (unique_key = self.public_send(attr_name)).blank?
        raise UnknownUniqueValue, "unique keyとして指定された値(#{attr_name})が取得できません"
      end
      [self.class.name, unique_key].join(REDIS_KEY_DELIMITER)
    end

    # 引数で指定した時間にexpireするためのttl値を生成
    # @example
    #   # 2016/10/26 正午にexpireする
    #   redis.setex(key, ttl_to(Time.zone.parse("2016-10-26 12:00:00")), value)
    #   # 24時間後にexpireする
    #   redis.setex(key, ttl_to(1.day.since), value)
    # @param [Time] to_time expireする時間
    # @param [Time] from_time 現在時間
    # @param [Boolean] unsigned_non_zero 計算結果のttlが0の場合1を返す
    # @return [Integer]
    def ttl_to(to_time, from_time = Time.current, unsigned_non_zero: true)
      ttl = (to_time - from_time).to_i
      return ttl if ttl > 0
      unsigned_non_zero ? 1 : ttl
    end

    # Redis.currentへのショートカット
    # @return [Redis]
    def redis
      self.class.redis
    end
  end
end
