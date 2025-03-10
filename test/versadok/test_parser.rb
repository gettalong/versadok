require 'test_helper'
require 'versadok/parser'

describe VersaDok::Parser::Stack do
  before do
    @stack = VersaDok::Parser::Stack.new(node(:root))
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

  describe "node_index" do
    it "returns the highest index of the node with the given type" do
      @stack.append_child(node(:strong))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:other))
      assert_equal(2, @stack.node_index(:strong))
    end

    it "returns nil if no node with the given type exists" do
      @stack.append_child(node(:other))
      assert_nil(@stack.node_index(:strong))
    end
  end

  describe "close_node" do
    it "closes the given node" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:text, properties: {content: 'test'}), container: false)
      @stack.close_node(@stack.node_index(:strong))
      assert_equal(:paragraph, @stack.container.type)
      @stack.reset_level(-1)
      assert_equal(:paragraph, @stack.container.type)
    end

    it "stops processing when encountering a non-inline node" do
      @stack.append_child(node(:first))
      @stack.append_child(node(:second))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:text, properties: {content: 'test'}), container: false)
      @stack.close_node(@stack.node_index(:first))
      assert_equal(:root, @stack.container.type)
      assert_equal(:second, @stack.container.children[0].children[0].type)
    end

    it "removes unclosed child node with text node before" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:text, properties: {content: +'before'}), container: false)
      @stack.append_child(node(:emphasis, properties: {marker: '_'}))
      @stack.append_child(node(:text, properties: {content: +'emph'}), container: false)
      @stack.close_node(@stack.node_index(:strong))
      assert_equal(:paragraph, @stack.container.type)
      assert_equal('before_emph', @stack.container.children[0].children[0][:content])
    end

    it "removes unclosed child node with no text node before" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:emphasis, properties: {marker: '_'}))
      @stack.append_child(node(:text, properties: {content: +'emph'}), container: false)
      @stack.close_node(@stack.node_index(:strong))
      assert_equal(:paragraph, @stack.container.type)
      assert_equal('_emph', @stack.container.children[0].children[0][:content])
    end

    it "removes unclosed child node with non-text node as first child" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:emphasis, properties: {marker: '_'}))
      @stack.append_child(node(:nontext, properties: {marker: '+'}))
      @stack.append_child(node(:text, properties: {content: +'emph'}), container: false)
      @stack.close_node(@stack.node_index(:nontext))
      @stack.close_node(@stack.node_index(:strong))
      assert_equal(:paragraph, @stack.container.type)
      assert_equal('_', @stack.container.children[0].children[0][:content])
    end

    it "removes unclosed child node with no children" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:emphasis, properties: {marker: '_'}))
      @stack.close_node(@stack.node_index(:strong))
      assert_equal(:paragraph, @stack.container.type)
      assert_equal('_', @stack.container.children[0].children[0][:content])
    end

    it "works for inline nodes without a marker property" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:emphasis))
      @stack.close_node(@stack.node_index(:strong))

      @stack.append_child(node(:strong))
      @stack.append_child(node(:text, properties: {content: +'emph'}), container: false)
      @stack.append_child(node(:emphasis))
      @stack.close_node(@stack.node_index(:strong))
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

    it "ensures that unclosed inline children are removed" do
      n = node(:block, properties: {category: :block})
      @stack.append_child(n)
      @stack.append_child(node(:strong, properties: {marker: '*'}))
      @stack.append_child(node(:text, properties: {content: 'test'}), container: false)
      @stack.reset_level
      @stack.append_child(node(:blank))
      assert_equal(1, n.children.size)
      assert_equal('*test', n.children[0][:content])
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
    root = @parser.parse(str).finish
    assert_equal(1, root.children.size)
    retval = root.children[0]
    assert_equal(type, retval.type)
    assert_equal(child_count, retval.children.size)
    retval
  end

  def parse_multi(str, count)
    root = @parser.parse(str).finish
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
      children = parse_multi("  \r  \r\n  \n", 1)
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
      header = parse_single("# header\ncontin\r\n  ued\r# here\n## and here", :header, 1)
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
      para = parse_single(">\r>\r\n>\n>", :paragraph, 1)
      assert_equal("> > > >", para.children[0][:content])
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

  describe "parse_list_item" do
    it "sets the indent property on the list and list item" do
      list = parse_single("   *   item", :list, 1)
      assert_equal(0, list[:indent])
      assert_equal(4, list.children.last[:indent])
    end

    it "collects list items of the same marker type into one list" do
      parse_single("    * item 1\n* item 2", :list, 2)
    end

    it "creates separate lists for different marker types" do
      nodes = parse_multi("* bullet\n\n- other bullet\n\n1. decimal", 3)
      assert_equal(:asterisk, nodes[0][:marker])
      assert_equal(:minus, nodes[1][:marker])
      assert_equal(:decimal, nodes[2][:marker])
    end

    it "treats list items that would start a new list but are not on a block boundary as " \
       "continuation lines" do
      list = parse_single("* item1\n- item2", :list, 1)
      assert_equal("item1 - item2", list.children[0].children[0].children[0][:content])
    end

    it "works for bullet lists using asterisks" do
      list = parse_single("* item", :list, 1)
      assert_equal(:asterisk, list[:marker])
    end

    it "works for bullet lists using pluses" do
      list = parse_single("+ item", :list, 1)
      assert_equal(:plus, list[:marker])
    end

    it "works for bullet lists using minuses" do
      list = parse_single("- item", :list, 1)
      assert_equal(:minus, list[:marker])
    end

    it "works for ordered lists using decimals" do
      list = parse_single("1. item", :list, 1)
      assert_equal(:decimal, list[:marker])
    end

    it "sets the start number for an ordered list" do
      list = parse_single("42. item", :list, 1)
      assert_equal(42, list[:start])
    end

    it "ignores the list marker if it doesn't constitute a correct marker" do
      nodes = parse_multi("*para\n\n1para\n\n1- para", 5)
      nodes.values_at(0, 2, 4).each {|node| assert_equal(:paragraph, node.type) }
    end
  end

  describe "parse_extension_block" do
    class TestExtension < VersaDok::Extension
      attr_reader :result

      def parse_content?; false; end
      def parse_line(str); (@lines ||= []) << str end
      def parsing_finished!; @result = @lines.join end
    end

    it "parses the extension name" do
      node = parse_single("::mark:", :extension_block, 0)
      assert_equal("mark", node[:name])
    end

    it "sets the indentation correctly" do
      node = parse_single("  ::mark: indent=5", :extension_block, 0)
      assert_equal(3, node[:indent])
    end

    it "parses the attribute list on the marker line" do
      node = parse_single("  ::mark: key=value .class #id ref", :extension_block, 0)
      assert_equal({'class' => 'class', 'id' => 'id', 'key' => 'value'}, node.attributes)
      assert_equal(['ref'], node[:refs])
    end

    it "parses the content as block elements by default" do
      node = parse_single("::mark:\n para\ngraph\n\n > block", :extension_block, 3)
      assert_equal(:block, node.content_model)
      assert_equal("para graph", node.children[0].children[0][:content])
      assert_equal(:blockquote, node.children[2].type)
    end

    it "defers parsing to the extension if specified" do
      @parser.extensions["mark"] = ext = TestExtension.new
      node = parse_single("::mark:\n  para\n  graph\n     \n\n  > block", :extension_block, 0)
      assert_equal(:special, node.content_model)
      assert_equal("para\ngraph\n   \n\n> block", ext.result)
    end

    it "recognizes the 'indent' attribute when deferring parsing to the extension" do
      @parser.extensions["mark"] = ext = TestExtension.new
      parse_single("::mark: indent=4\n    para\n      graph\n   \n\n    > block",
                   :extension_block, 0)
      assert_equal("para\n  graph\n\n\n> block", ext.result)
    end

    it "doesn't allow a custom 'indent' less than the default indentation" do
      @parser.extensions["mark"] = ext = TestExtension.new
      parse_single("  ::mark: indent=2\n    para\n      graph\n   \n\n    > block",
                   :extension_block, 0)
      assert_equal(" para\n   graph\n\n\n > block", ext.result)
    end

    it "ignores the marker if it doesn't constitute a correct marker" do
      nodes = parse_multi("::para\n  another", 1)
      assert_equal(:paragraph, nodes[0].type)
      assert_equal("::para another", nodes[0].children[0][:content])
    end

    it "creates an appropriate block for an invalidly unindented, directly following content line" do
      nodes = parse_multi("::para:\n# another", 2)
      assert_equal(:extension_block, nodes[0].type)
      assert_equal(:paragraph, nodes[1].type)
      assert_equal("# another", nodes[1].children[0][:content])
    end
  end

  describe "parse_attribute_list" do
    it "recognizes IDs" do
      assert_equal({"id" => "id"}, @parser.send(:parse_attribute_list, +"#id"))
    end

    it "recognizes class names" do
      assert_equal({"class" => "cls1 cls2"}, @parser.send(:parse_attribute_list, +".cls1 .cls2"))
    end

    it "recognizes references" do
      assert_equal({refs: ["ähm.cl#3", "omy"]}, @parser.send(:parse_attribute_list, +"ähm.cl#3 omy"))
    end

    it "recognizes key-value pairs without quoting" do
      assert_equal({"key" => "value"}, @parser.send(:parse_attribute_list, +"key=value"))
    end

    it "recognizes key-value pairs with single quotes" do
      assert_equal({"key" => "value"}, @parser.send(:parse_attribute_list, +"key='value'"))
    end

    it "recognizes key-value pairs with double quotes" do
      assert_equal({"key" => "value"}, @parser.send(:parse_attribute_list, +"key=\"value\""))
    end

    it "removes escaped closing braces from values of key-value pairs" do
      assert_equal({"key" => "}pair"}, @parser.send(:parse_attribute_list, +"key=\\}pair"))
    end

    it "removes the escaped quote character from values of key-value pairs" do
      assert_equal({"key" => "this'is"}, @parser.send(:parse_attribute_list, +"key='this\\'is'"))
    end

    it "ignores escaped characters except for the closing brace and quote character" do
      assert_equal({"key" => "t\\his'is"}, @parser.send(:parse_attribute_list, +"key='t\\his\\'is'"))
    end

    it "doesn't allow unescaped closing braces anywhere" do
      assert_equal({}, @parser.send(:parse_attribute_list, +"#id}a .cl}ass re}e key=val}ue"))
    end

    it "works for empty strings" do
      assert_equal({}, @parser.send(:parse_attribute_list, +""))
    end
  end

  describe "parse_inline_simple" do
    it "works for content marked-up with strong" do
      node = parse_single("*home*", :paragraph, 1)
      assert_equal(:strong, node.children[0].type)
    end

    it "works for content marked-up with emphasis" do
      node = parse_single("_home_", :paragraph, 1)
      assert_equal(:emphasis, node.children[0].type)
    end

    it "works inside of words" do
      node = parse_single("a*test*b", :paragraph, 3)
      assert_equal(:strong, node.children[1].type)
      assert_equal("a", node.children[0][:content])
      assert_equal("b", node.children[2][:content])
    end

    it "ignores closing markers when element has not been opened" do
      node = parse_single("a* test", :paragraph, 1)
      assert_equal("a* test", node.children[0][:content])
    end

    it "ignores markers with whitespace around them" do
      node = parse_single("a * b*", :paragraph, 1)
      assert_equal("a * b*", node.children[0][:content])
    end

    it "doesn't allow nesting same-type elements" do
      node = parse_single("a*test *b* test*", :paragraph, 3)
      assert_equal(:strong, node.children[1].type)
      assert_equal("a", node.children[0][:content])
      assert_equal("test *b", node.children[1].children[0][:content])
      assert_equal(" test*", node.children[2][:content])
    end

    it "works directly before continuation lines borders" do
      node = parse_single("*test*\n_hallo_", :paragraph, 3)
      assert_equal(:strong, node.children[0].type)
      assert_equal(:emphasis, node.children[2].type)
      assert_equal(" ", node.children[1][:content])
    end

    it "works across continuation lines" do
      node = parse_single("*test\rhallo*", :paragraph, 1)
      assert_equal(:strong, node.children[0].type)
      assert_equal("test hallo", node.children[0].children[0][:content])
    end

    it "handles unclosed nodes" do
      node = parse_single("_home *star_ *home _star*", :paragraph, 3)
      assert_equal(:emphasis, node.children[0].type)
      assert_equal(:text, node.children[1].type)
      assert_equal(:strong, node.children[2].type)
      assert_equal('home *star', node.children[0].children[0][:content])
      assert_equal('home _star', node.children[2].children[0][:content])
    end
  end
end
