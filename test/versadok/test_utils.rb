require 'test_helper'
require 'versadok/utils'

describe VersaDok::Utils::HashDeepMerge do
  using VersaDok::Utils::HashDeepMerge

  describe "deep_merge!" do
    it "does nothing special for unnested hashes" do
      hash = {a: 1, b: 2, c: 3}
      other = {a: 5}
      assert_same(hash, hash.deep_merge!(other))
      assert_equal({a: 5, b: 2, c: 3}, hash)
    end

    it "merges nested hashes with the equivalent in other" do
      hash = {a: 1, b: {e: 2, f: 4}, c: 3}
      other = {b: {e: 5}}
      hash.deep_merge!(other)
      assert_equal(5, hash.dig(:b, :e))
    end

    it "just uses the nested other value if it is not a Hash" do
      hash = {a: 1, b: {e: 2, f: 4}, c: 3}
      other = {b: 5}
      hash.deep_merge!(other)
      assert_equal(5, hash.dig(:b))
    end

    it "uses deep_merge instead of deep_merge! for nested hashes" do
      hash = {b: {e: 2, f: 4}}
      other = {b: {e: 5}}
      hash.deep_merge!(other)
      other[:b][:e] = 7
      assert_equal(5, hash.dig(:b, :e))
    end
  end

  it "duplicates the hash before deep merging" do
    hash = {a: 1, b: {e: 2, f: 4}, c: 3}
    other = {b: {e: 7, g: 8}}
    merged_hash = hash.deep_merge(other)
    refute_same(hash, merged_hash)
  end
end
