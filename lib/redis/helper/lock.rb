class Redis
  module Helper
    class Lock
      # ロック取得のタイムアウト(sec)
      DEFAULT_TIMEOUT = 5

      def initialize(redis, lock_key, options = {})
        @redis        = redis
        @lock_key     = lock_key
        @options      = options
        @locked_by_self = false
      end

      # ロックをかけてブロック内の処理を実行
      # @yield ロック中に実行する処理のブロック
      def lock
        raise ArgumentError unless block_given?
        if Thread.current[@lock_key]
          yield
        else
          begin
            Thread.current[@lock_key] = true
            try_lock!(Time.now.to_f)
            yield
          ensure
            unlock
            Thread.current[@lock_key] = nil
          end
        end
      end

      # ロックを開放
      # (自身でかけたロックの場合のみ開放する)
      def unlock
        if @locked_by_self
          @redis.del(@lock_key)
          @locked_by_self = false
        end
      end

      private
        # ロックを取得
        # @param [Float] start ロック取得開始時間のUNIXタイムスタンプ
        # @yield ロック中に実行する処理のブロック
        # @raise [Redis::Helper::LockTimeout] ロックの取得に失敗した
        def try_lock!(start)
          loop do
            if @redis.setnx(@lock_key, expiration)
              @locked_by_self = true
              break
            end

            current = @redis.get(@lock_key).to_f
            if current < Time.now.to_f
              old = @redis.getset(@lock_key, expiration).to_f
              if old < Time.now.to_f
                @locked_by_self = true
                break
              end
            end

            Kernel.sleep(0.1)
            raise ::Redis::Helper::LockTimeout if (Time.now.to_f - start) > timeout
          end
        end

        # ロックの有効期限
        # @return [Float] 有効期限(UNIXタイムスタンプ)
        def expiration
          (Time.now + timeout).to_f
        end

        # ロック取得と取得したロックがタイムアウトするまでの時間
        # @return [Float] タイムアウト時間(sec)
        def timeout
          @timeout ||= (@options[:timeout] || DEFAULT_TIMEOUT).to_f
        end
    end
  end
end
