require 'test_helper'
require 'versadok/parser'

describe VersaDok::Node do
  def node(type)
    VersaDok::Node.new(type)
  end

  before do
    @node = node(:root)
  end

  describe "category" do
    it "returns the set category" do
      @node.properties = {category: :inline}
      assert_equal(:inline, @node.category)
    end

    it "returns the pre-defined category if none is set" do
      assert_equal(:block, @node.category)
    end
  end

  describe "content_model" do
    it "returns the set content model" do
      @node.properties = {content_model: :span}
      assert_equal(:span, @node.content_model)
    end

    it "returns the pre-defined content model if none is set" do
      assert_equal(:block, @node.content_model)
    end
  end

  it "returns the value of a property with #[]" do
    assert_nil(@node[:test])
    @node.properties = {test: :value}
    assert_equal(:value, @node[:test])
  end

  it "can append child nodes with #<<" do
    @node << node(:child)
    assert_equal([:child], @node.children.map(&:type))
  end

  it "can output itself as string" do
    assert_equal("root", @node.to_s)
    @node.properties = {test: :value}
    assert_equal("root #{@node.properties}", @node.to_s)
    @node.attributes = {"key": "value"}
    assert_equal("root #{@node.properties} key=\"value\"", @node.to_s)
    @node << (node(:child1) << node(:level2))
    @node << node(:child2)
    @node << node(:child3)
    assert_equal("root #{@node.properties} key=\"value\"\n" \
                 "  child1\n    level2\n  child2\n  child3", @node.to_s)
  end
end
