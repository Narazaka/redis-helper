require "spec_helper"

class Foo
  include Redis::Helper

  attr_reader :id, :number, :empty_key

  def initialize(id, number)
    @id = id
    @number = number
  end
end

class Bar < Foo
  define_attr_keys :hoge, :piyo, unique_attr: :id
  define_attr_keys :hoge_by_number, unique_attr: :number
end

describe Redis::Helper do
  let(:base_key) { "lock_example" }

  it "has a version number" do
    expect(Redis::Helper::VERSION).not_to be nil
  end

  describe "helper methods" do
    let(:foo) { Foo.new(42, 114514) }

    describe "#redis" do
      subject { foo.redis }
      it("== Redis.current") { is_expected.to eq(Redis.current) }
    end

    describe "#redis=" do
      before { Foo.redis = double("redis") }
      after { Foo.redis = nil }
      subject { foo.redis }
      it "custom redis connection" do
        is_expected.not_to eq(Redis.current)
      end
    end

    describe "#attr_key" do
      context "default unique_attr" do
        subject { foo.attr_key(:bar) }
        it { is_expected.to eq("Foo:42:bar") }
      end

      context "another unique_attr" do
        subject { foo.attr_key(:bar, :number) }
        it { is_expected.to eq("Foo:114514:bar") }
      end

      context "empty unique_attr" do
        subject { -> { foo.attr_key(:bar, :empty_key) } }
        it { is_expected.to raise_error(Redis::Helper::UnknownUniqueValue) }
      end
    end

    describe "#ttl_to" do
      subject { foo.ttl_to(to_time, from_time) }
      let(:from_time) { Time.current }
      let(:to_time) { from_time + offset }

      context "default from_time" do
        let(:offset) { 1000 }
        subject { foo.ttl_to(to_time) }
        it { is_expected.to be > 0 }
        it { is_expected.to be <= offset }
      end

      context "future" do
        let(:offset) { 1000 }
        it { is_expected.to eq(offset) }
      end

      context "just now" do
        let(:offset) { 0 }
        it { is_expected.to eq(1) }
      end

      context "just now with unsigned_non_zero: false" do
        let(:offset) { 0 }
        subject { foo.ttl_to(to_time, from_time, unsigned_non_zero: false) }
        it { is_expected.to eq(0) }
      end
    end

    describe "#lock" do
      it "delegate to .lock method" do
        expect(Foo).to receive(:lock).with(base_key)
        foo.lock(base_key)
      end
    end
  end

  describe ".attr_key" do
    let(:bar) { Bar.new(42, 114514) }
    context "default unique_attr 1" do
      subject { bar.hoge_key }
      it { is_expected.to eq("Bar:42:hoge") }
    end

    context "default unique_attr 2" do
      subject { bar.piyo_key }
      it { is_expected.to eq("Bar:42:piyo") }
    end

    context "custom unique_attr" do
      subject { bar.hoge_by_number_key }
      it { is_expected.to eq("Bar:114514:hoge_by_number") }
    end
  end

  describe ".lock" do
    let(:lock_key) {
      [base_key, ::Redis::Helper::LOCK_POSTFIX].join(::Redis::Helper::REDIS_KEY_DELIMITER)
    }

    it "create Redis::Helper::Lock intance with lock_key and call #lock" do
      expect(obj = double("Redis::Helper::Lock")).to receive(:lock)
      expect(::Redis::Helper::Lock).to receive(:new).with(Foo.redis, lock_key).and_return(obj)
      Foo.lock(base_key)
    end
  end
end
