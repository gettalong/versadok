require 'test_helper'
require 'versadok/parser'

describe VersaDok::Parser::Stack do
  before do
    @stack = VersaDok::Parser::Stack.new(node(:root, properties: {indent: 0}))
  end

  def node(type, **args)
    VersaDok::Node.new(type, **args)
  end

  describe "container" do
    it "returns the current container element" do
      assert_equal(@stack[0], @stack.container)
      @stack.append_child(node(:test))
      assert_equal(:test, @stack.container.type)
    end
  end

  describe "block_boundary?" do
    it "returns true if no child element is at the current level" do
      assert(@stack.block_boundary?)
      @stack.append_child(node(:test))
      @stack.reset_level
      refute(@stack.block_boundary?)
    end

    it "returns true if the last appended child element was of type :blank" do
      @stack.append_child(node(:test))
      @stack.append_child(node(:blank), container: false)
      @stack.reset_level
      assert(@stack.block_boundary?)
    end
  end

  describe "last_child" do
    it "returns the last appended child of the current container" do
      assert_nil(@stack.last_child)
      @stack.append_child(node(:test))
      @stack.reset_level
      assert_equal(:test, @stack.last_child.type)
    end
  end

  describe "[]" do
    it "returns the node at the given level in the stack" do
      assert_equal(:root, @stack[0].type)
      @stack.append_child(node(:test))
      assert_equal(:test, @stack[1].type)
    end
  end

  describe "reset_level" do
    before do
      @stack.append_child(node(:level1))
      @stack.append_child(node(:level2))
    end

    it "changes the current level to the given one" do
      @stack.reset_level(0)
      assert_equal(:root, @stack.container.type)
      @stack.reset_level(1)
      assert_equal(:level1, @stack.container.type)
    end

    it "allows using negative level number to count from the top of the stack" do
      @stack.reset_level(-2)
      assert_equal(:level1, @stack.container.type)
    end
  end

  describe "enter" do
    it "moves the current level one step up" do
      @stack.append_child(node(:level1))
      @stack.reset_level
      @stack.enter
      assert_equal(:level1, @stack.container.type)
    end
  end

  describe "enter_indented" do
    it "changes the current level to the first one with at least the given indentation" do
      @stack.append_child(node(:list, properties: {indent: 0}))
      @stack.append_child(node(:list_item1, properties: {indent: 2}))
      @stack.append_child(node(:list, properties: {indent: 0}))
      @stack.append_child(node(:list_item2, properties: {indent: 4}))

      @stack.reset_level
      @stack.enter_indented(2)
      assert_equal(:list_item1, @stack.container.type)

      @stack.reset_level
      @stack.enter_indented(5)
      assert_equal(:list_item2, @stack.container.type)
    end

    it "stops at elements that have no indent defined" do
      @stack.append_child(node(:list_item, properties: {indent: 2}))
      @stack.append_child(node(:test))
      @stack.append_child(node(:test2))
      @stack.reset_level
      @stack.enter_indented(5)
      assert_equal(:list_item, @stack.container.type)
    end

    it "stops if no more elements are available" do
      @stack.append_child(node(:list, properties: {indent: 2}))
      @stack.append_child(node(:list_item, properties: {indent: 5}))
      @stack.reset_level
      @stack.enter_indented(10)
      assert_equal(:list_item, @stack.container.type)
    end
  end

  describe "append_child" do
    it "appends a child to the only stack node" do
      n = node(:child)
      @stack.append_child(n)
      assert_equal([n], @stack[0].children)
      assert_equal(n, @stack.container)
    end

    it "appends a child to the first stack node" do
      @stack.append_child(node(:other))
      @stack.reset_level
      n = node(:child)
      @stack.append_child(n)
      assert_equal(n, @stack[0].children[1])
      assert_equal(n, @stack.container)
    end

    it "appends a child to a node in the middle of the stack" do
      @stack.append_child(node(:level1))
      @stack.append_child(node(:level12))
      @stack.reset_level(1)
      n = node(:child)
      @stack.append_child(n)
      assert_equal(n, @stack[1].children[1])
      assert_equal(n, @stack.container)
    end

    it "appends a child to the last stack node" do
      @stack.append_child(node(:other))
      n = node(:child)
      @stack.append_child(n)
      assert_equal([n], @stack[1].children)
      assert_equal(n, @stack.container)
    end
  end

  it "can output the stack as a string" do
    @stack.append_child(node(:level1))
    @stack.append_child(node(:level2))
    assert_equal("root -> level1 -> [level2]", @stack.to_s)
    @stack.reset_level(-2)
    assert_equal("root -> [level1] -> level2", @stack.to_s)
  end
end

describe VersaDok::Parser do
  before do
    @parser = VersaDok::Parser.new
  end

  def parse_single(str, type, child_count)
    root = @parser.parse(str)
    assert_equal(1, root.children.size)
    retval = root.children[0]
    assert_equal(type, retval.type)
    assert_equal(child_count, retval.children.size)
    retval
  end

  def parse_multi(str, count)
    root = @parser.parse(str)
    assert_equal(count, root.children.size)
    root.children
  end

  describe "parse_line" do
    it "handles empty input" do
      parse_multi("", 0)
    end

    it "handles a single blank input line with not line separator at the end" do
      children = parse_multi("   ", 1)
      assert_equal(:blank, children[0].type)
    end

    it "handles a single blank input line" do
      children = parse_multi("   \n", 1)
      assert_equal(:blank, children[0].type)
    end

    it "handles multiple blank input lines" do
      children = parse_multi("   \n   \n   ", 1)
      assert_equal(:blank, children[0].type)
    end

    it "handles CR, LF and CRLF line endings" do
      children = parse_multi("\r\r\n\n", 1)
      assert_equal(:blank, children[0].type)
    end
  end

  describe "parse_header" do
    1.upto(6) do |level|
      it "parses the header level #{level}" do
        header = parse_single("#{'#' * level} header", :header, 1)
        assert_equal(level, header[:level])
        assert_equal("header", header.children[0][:content])
      end
    end

    it "parses multiple headers" do
      elements = parse_multi("# header 1\n\n## header 2\r\n\n### header 3", 5)
      assert_equal(:header, elements[0].type)
      assert_equal(:blank,  elements[1].type)
      assert_equal(:header, elements[2].type)
      assert_equal(:blank,  elements[3].type)
      assert_equal(:header, elements[4].type)
    end

    it "allows whitespace before the marker" do
      parse_single("   \t# Test", :header, 1)
    end

    it "parses continuation lines" do
      header = parse_single("# header\ncontin\n  ued\n# here\n## and here", :header, 1)
      assert_equal("header contin ued here ## and here", header.children[0][:content])
    end

    it "ignores the marker if not followed by a space" do
      para = parse_single("#header", :paragraph, 1)
      assert_equal("#header", para.children[0][:content])
    end

    it "ignores the marker on a continuation line when not already in a header" do
      para = parse_single("Para\n# header", :paragraph, 1)
      assert_equal("Para # header", para.children[0][:content])
    end
  end

  describe "parse_blockquote" do
    it "parses a simple blockquote" do
      bq = parse_single("> Test", :blockquote, 1)
      assert_equal(:paragraph, bq.children[0].type)
      assert_equal("Test", bq.children[0].children[0][:content])
    end

    it "allows whitespace before the marker" do
      parse_single("   \t> Test", :blockquote, 1)
    end

    it "handles a line with just the marker and nothing else as paragraph" do
      para = parse_single(">\r>\r\n>\n", :paragraph, 1)
      assert_equal("> > > ", para.children[0][:content])
    end

    it "parses lines with the marker and nothing else on the line" do
      bq = parse_single("> Test1\n>\r>\r\n>\n> Test2", :blockquote, 3)
      assert_equal(:paragraph, bq.children[0].type)
      assert_equal(:blank, bq.children[1].type)
      assert_equal(:paragraph, bq.children[2].type)
      assert_equal("Test2", bq.children[2].children[0][:content])
    end

    it "handles a mix of markers with no content" do
      bq = parse_single("> \n>\n> \n", :blockquote, 1)
      assert_equal(:blank, bq.children[0].type)
    end

    it "parses continuation lines with the marker" do
      bq = parse_single("> Test\n> other", :blockquote, 1)
      assert_equal(:paragraph, bq.children[0].type)
      assert_equal("Test other", bq.children[0].children[0][:content])
    end

    it "parses continuation lines without the marker" do
      bq = parse_single("> Test1\nTest2", :blockquote, 1)
      assert_equal(:paragraph, bq.children[0].type)
      assert_equal("Test1 Test2", bq.children[0].children[0][:content])
    end

    it "ignores markers when not on block boundary" do
      para = parse_single("Para\n> test", :paragraph, 1)
      assert_equal("Para > test", para.children[0][:content])
    end

    it "ignores marker if not followed by a space" do
      para = parse_single(">Para", :paragraph, 1)
      assert_equal(">Para", para.children[0][:content])
    end

    it "only allows the marker followed by line break during a blockquote, not at the start" do
      parse_single(">\n> Test", :paragraph, 1)
    end
  end
end
