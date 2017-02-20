require "spec_helper"

describe Redis::Helper::Lock do
  let!(:now)     { Time.now }
  let(:redis)    { Redis.current }
  let(:lock_key) { "lock_example" }
  let(:lock)     { ::Redis::Helper::Lock.new(redis, lock_key) }

  describe "#lock" do
    it "duplication flag changed true" do
      expect(Thread.current[lock_key]).to be_nil
      expect(lock.lock { Thread.current[lock_key] }).to be_truthy
      expect(Thread.current[lock_key]).to be_nil
    end

    it "locked inside block" do
      expect(redis.exists(lock_key)).to be_falsey
      expect(lock.lock { redis.exists(lock_key) }).to be_truthy
      expect(redis.exists(lock_key)).to be_falsey
    end

    it "raise ArgumentError if block not given" do
      expect { lock.lock }.to raise_error(ArgumentError)
    end

    it "don't double lock" do
      expect(lock).to receive(:try_lock!).once
      lock.lock { lock.lock {} }
    end
  end

  describe "#unlock" do
    it "do nothing if not locked by self" do
      expect(redis).not_to receive(:del)
      lock.unlock
    end

    context "locked by self" do
      before { lock.send(:try_lock!, now.to_f) }
      it "remove lock flag" do
        expect {
          lock.unlock
        }.to change { redis.exists(lock_key) }.to(false).from(true)
      end
      it "locked_by_self changed false" do
        expect {
          lock.unlock
        }.to change { lock.instance_eval { @locked_by_self } }.to(false).from(true)
      end
    end
  end

  describe "#try_lock!" do
    after { redis.del(lock_key) }

    context "not conflict" do
      before { expect(redis).not_to receive(:get) }
      it "get lock" do
        expect {
          lock.send(:try_lock!, now.to_f)
        }.to change { redis.exists(lock_key) }.to(true).from(false)
      end
      it "locked_by_self changed true" do
        expect {
          lock.send(:try_lock!, now.to_f)
        }.to change { lock.instance_eval { @locked_by_self } }.to(true).from(false)
      end
    end

    context "conflict with expired lock" do
      let!(:old_expiration) { (now - 1).to_f }
      before { redis.set(lock_key, old_expiration) }
      it "get lock" do
        expect {
          lock.send(:try_lock!, now.to_f)
        }.to change { redis.get(lock_key).to_f }.from(old_expiration)
      end
      it "locked_by_self changed true" do
        expect {
          lock.send(:try_lock!, now.to_f)
        }.to change { lock.instance_eval { @locked_by_self } }.to(true).from(false)
      end
    end

    context "conflict with valid lock" do
      let!(:valid_expiration) { (now + 3600).to_f }
      before do
        lock.instance_eval { @options[:timeout] = 0.3 } # for reduced testing time
        redis.set(lock_key, valid_expiration)
      end
      it "raise LockTimeout" do
        expect {
          lock.send(:try_lock!, now.to_f)
        }.to raise_error(::Redis::Helper::LockTimeout)
      end
    end
  end

  describe "#expiration" do
    before { allow(Time).to receive(:now).and_return(now) }
    subject { lock.send(:expiration) }
    it { is_expected.to eq(now.to_f + ::Redis::Helper::Lock::DEFAULT_TIMEOUT) }
  end

  describe "#timeout" do
    it "returns default timeout" do
      expect(lock.send(:timeout)).to eq(::Redis::Helper::Lock::DEFAULT_TIMEOUT)
    end

    context "with options" do
      let(:timeout) { 10 }
      let(:lock_with_options) { ::Redis::Helper::Lock.new(redis, lock_key, timeout: timeout) }
      subject { lock_with_options.send(:timeout) }
      it { is_expected.to eq(timeout) }
    end
  end
end
