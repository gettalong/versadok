require 'test_helper'
require 'versadok/parser'

describe VersaDok::Parser::Stack do
  before do
    @stack = VersaDok::Parser::Stack.new(node(:root))
  end

  def node(type)
    VersaDok::Node.new(type)
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
