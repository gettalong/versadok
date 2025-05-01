require 'test_helper'
require 'versadok/renderer'
require 'versadok/context'
require 'versadok/node'

describe VersaDok::Renderer do
  before do
    @context = VersaDok::Context.new
    @renderer = VersaDok::Renderer.new(@context)
  end

  describe "initialize" do
    it "needs the context object as argument" do
      assert_equal(@context, @renderer.context)
    end
  end

  describe "render" do
    it "calls the correct render_TYPE method" do
      renders_children = [:root, :paragraph, :header, :blockquote, :list, :list_item,
                          :span, :link, :strong, :emphasis, :subscript, :superscript]
      renders_nothing = [:blank, :text, :soft_break, :hard_break, :verbatim,
                         :extension_block, :inline_extension]

      [[renders_children, true], [renders_nothing, false]].each do |types, test_children|
        types.each do |type|
          node = VersaDok::Node.new(type)

          called = false
          @renderer.stub(:"render_#{type}", lambda {|n| called = true; assert_same(node, n) }) do
            @renderer.render(node)
          end
          assert(called)

          next unless test_children
          called = false
          @renderer.stub(:"render_children", lambda {|n| called = true; assert_same(node, n) }) do
            @renderer.render(node)
          end
          assert(called)
        end
      end
    end

    it "fails for unsupported node types" do
      assert_raises(RuntimeError) { @renderer.render(VersaDok::Node.new(:unsupported)) }
    end

    it "renders the children" do
      node = VersaDok::Node.new(:root)
      node << VersaDok::Node.new(:paragraph)
      called = false
      @renderer.stub(:render_paragraph, lambda {|_n| called = true }) do
        @renderer.render(node)
      end
      assert(called)
    end
  end
end
