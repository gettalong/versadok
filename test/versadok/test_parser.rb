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

  describe "node_level" do
    it "returns the highest index of the node with the given type" do
      @stack.append_child(node(:strong))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:other))
      assert_equal(2, @stack.node_level(:strong))
    end

    it "stops searching at elements containing verbatim content" do
      @stack.append_child(node(:strong))
      @stack.append_child(node(:verbatim))
      @stack.append_child(node(:other))
      assert_nil(@stack.node_level(:strong))
    end

    it "returns the top verbatim element if searched for" do
      @stack.append_child(node(:verbatim))
      @stack.append_child(node(:span_data))
      @stack.append_child(node(:other))
      assert_equal(2, @stack.node_level(:span_data))
      assert_nil(@stack.node_level(:verbatim))
    end

    it "returns nil if no node with the given type exists" do
      @stack.append_child(node(:other))
      assert_nil(@stack.node_level(:strong))
    end
  end

  describe "close_node" do
    it "closes the given node" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:text, content: 'test'), container: false)
      @stack.close_node(@stack.node_level(:strong))
      assert_equal(:paragraph, @stack.container.type)
      @stack.reset_level(-1)
      assert_equal(:paragraph, @stack.container.type)
    end

    it "stops processing when encountering a non-inline node" do
      @stack.append_child(node(:first))
      @stack.append_child(node(:second))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:text, content: 'test'), container: false)
      @stack.close_node(@stack.node_level(:first))
      assert_equal(:root, @stack.container.type)
      assert_equal(:second, @stack.container.children[0].children[0].type)
    end

    it "removes unclosed child node with text node before" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:text, content: +'before'), container: false)
      @stack.append_child(node(:emphasis, properties: {marker: '_'}))
      @stack.append_child(node(:text, content: +'emph'), container: false)
      @stack.close_node(@stack.node_level(:strong))
      assert_equal(:paragraph, @stack.container.type)
      assert_equal('before_emph', @stack.container.children[0].children[0].content)
    end

    it "removes unclosed child node with no text node before" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:emphasis, properties: {marker: '_'}))
      @stack.append_child(node(:text, content: +'emph'), container: false)
      @stack.close_node(@stack.node_level(:strong))
      assert_equal(:paragraph, @stack.container.type)
      assert_equal('_emph', @stack.container.children[0].children[0].content)
    end

    it "removes unclosed child node with non-text node as first child" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:emphasis, properties: {marker: '_'}))
      @stack.append_child(node(:nontext, properties: {marker: '+'}))
      @stack.append_child(node(:text, content: +'emph'), container: false)
      @stack.close_node(@stack.node_level(:nontext))
      @stack.close_node(@stack.node_level(:strong))
      assert_equal(:paragraph, @stack.container.type)
      assert_equal('_', @stack.container.children[0].children[0].content)
    end

    it "removes unclosed child node with no children" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:emphasis, properties: {marker: '_'}))
      @stack.close_node(@stack.node_level(:strong))
      assert_equal(:paragraph, @stack.container.type)
      assert_equal('_', @stack.container.children[0].children[0].content)
    end

    it "works for inline nodes without a marker property" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:strong))
      @stack.append_child(node(:emphasis))
      @stack.close_node(@stack.node_level(:strong))

      @stack.append_child(node(:strong))
      @stack.append_child(node(:text, content: +'emph'), container: false)
      @stack.append_child(node(:emphasis))
      @stack.close_node(@stack.node_level(:strong))
    end
  end

  describe "remove_node" do
    it "removes the node from the stack and its parent" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(node(:text), container: false)
      @stack.append_child(node(:link))
      @stack.append_child(node(:text), container: false)
      @stack.append_child(node(:strong))
      @stack.append_child(node(:text), container: false)
      @stack.append_child(node(:emphasis))
      node = @stack.remove_node(3)
      assert_equal(:strong, node.type)
      assert_equal(1, @stack[2].children.size)
      assert_equal(:text, @stack[2].children[0].type)
      assert_same(@stack[2], @stack.container)
      @stack.reset_level(-1)
      assert_same(@stack[2], @stack.container)
    end
  end

  describe "each_inline_verbatim" do
    it "iterates over all inline verbatim elements in reverse order" do
      @stack.append_child(node(:paragraph))
      @stack.append_child(n1 = node(:verbatim))
      @stack.append_child(n2 = node(:span_data))
      assert_equal([n2, n1], @stack.each_inline_verbatim.to_a)
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
      @stack.append_child(node(:text, content: 'test'), container: false)
      @stack.reset_level
      @stack.append_child(node(:blank))
      assert_equal(1, n.children.size)
      assert_equal('*test', n.children[0].content)
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
    @context = VersaDok::Context.new
    @parser = VersaDok::Parser.new(@context)
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
        assert_equal("header", header.children[0].content)
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
      header = parse_single("# header\ncontin\r\n  ued\r# here\\\n## and here", :header, 9)
      assert_equal("header", header.children[0].content)
      assert_equal("contin", header.children[2].content)
      assert_equal("ued", header.children[4].content)
      assert_equal("here", header.children[6].content)
      assert_equal("## and here", header.children[8].content)
    end

    it "ignores the marker if not followed by a space" do
      para = parse_single("#header", :paragraph, 1)
      assert_equal("#header", para.children[0].content)
    end

    it "ignores the marker on a continuation line when not already in a header" do
      para = parse_single("Para\n# header", :paragraph, 3)
      assert_equal("# header", para.children[2].content)
    end
  end

  describe "parse_blockquote" do
    it "parses a simple blockquote" do
      bq = parse_single("> Test", :blockquote, 1)
      assert_equal(:paragraph, bq.children[0].type)
      assert_equal("Test", bq.children[0].children[0].content)
    end

    it "allows whitespace before the marker" do
      parse_single("   \t> Test", :blockquote, 1)
    end

    it "handles a line with just the marker and nothing else as paragraph" do
      para = parse_single(">\r>\r\n>\n>", :paragraph, 7)
      [0, 2, 4, 6].each {|i| assert_equal(">", para.children[i].content) }
      [1, 3, 5].each {|i| assert_equal(:soft_break, para.children[i].type) }
    end

    it "parses lines with the marker and nothing else on the line" do
      bq = parse_single("> Test1\n>\r>\r\n>\n> Test2", :blockquote, 3)
      assert_equal(:paragraph, bq.children[0].type)
      assert_equal(:blank, bq.children[1].type)
      assert_equal(:paragraph, bq.children[2].type)
      assert_equal("Test2", bq.children[2].children[0].content)
    end

    it "handles a mix of markers with no content" do
      bq = parse_single("> \n>\n> \n", :blockquote, 1)
      assert_equal(:blank, bq.children[0].type)
    end

    it "parses continuation lines with the marker" do
      bq = parse_single("> Test\n> other", :blockquote, 1)
      assert_equal(:paragraph, bq.children[0].type)
      assert_equal("Test", bq.children[0].children[0].content)
      assert_equal(:soft_break, bq.children[0].children[1].type)
      assert_equal("other", bq.children[0].children[2].content)
    end

    it "parses continuation lines without the marker" do
      bq = parse_single("> Test1\nTest2", :blockquote, 1)
      assert_equal(:paragraph, bq.children[0].type)
      assert_equal("Test1", bq.children[0].children[0].content)
      assert_equal("Test2", bq.children[0].children[2].content)
    end

    it "ignores markers when not on block boundary" do
      para = parse_single("Para\n> test", :paragraph, 3)
      assert_equal("> test", para.children[2].content)
    end

    it "ignores marker if not followed by a space" do
      para = parse_single(">Para", :paragraph, 1)
      assert_equal(">Para", para.children[0].content)
    end

    it "only allows the marker followed by line break during a blockquote, not at the start" do
      parse_single(">\n> Test", :paragraph, 3)
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
      assert_equal("- item2", list.children[0].children[0].children[2].content)
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
    class ParserTestExtension < VersaDok::Extension
      attr_reader :result

      def self.extension_names = ['mark']
      def parse_content? = true
      def parse_line(str) = (@lines ||= []) << str
      def parsing_finished! = @result = @lines.join
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
      assert_equal("para", node.children[0].children[0].content)
      assert_equal("graph", node.children[0].children[2].content)
      assert_equal(:blockquote, node.children[2].type)
    end

    it "defers parsing to the extension if specified" do
      ext = @parser.context.add_extension(ParserTestExtension)
      node = parse_single("::mark:\n  para\n  graph\n     \n\n  > block", :extension_block, 0)
      assert_equal("para\ngraph\n   \n\n> block", ext.result)
    end

    it "recognizes the 'indent' attribute when deferring parsing to the extension" do
      ext = @parser.context.add_extension(ParserTestExtension)
      parse_single("::mark: indent=4\n    para\n      graph\n   \n\n    > block",
                   :extension_block, 0)
      assert_equal("para\n  graph\n\n\n> block", ext.result)
    end

    it "doesn't allow a custom 'indent' less than the default indentation" do
      ext = @parser.context.add_extension(ParserTestExtension)
      parse_single("  ::mark: indent=2\n    para\n      graph\n   \n\n    > block",
                   :extension_block, 0)
      assert_equal(" para\n   graph\n\n\n > block", ext.result)
    end

    it "ignores the marker if it doesn't constitute a correct marker" do
      nodes = parse_multi("::para\n  another", 1)
      assert_equal(:paragraph, nodes[0].type)
      assert_equal("::para", nodes[0].children[0].content)
      assert_equal(:soft_break, nodes[0].children[1].type)
      assert_equal("another", nodes[0].children[2].content)
    end

    it "creates an appropriate block for an invalidly unindented, directly following content line" do
      nodes = parse_multi("::para:\n# another", 2)
      assert_equal(:extension_block, nodes[0].type)
      assert_equal(:paragraph, nodes[1].type)
      assert_equal("# another", nodes[1].children[0].content)
    end
  end

  describe "parse_attribute_list" do
    it "applies the attribute list to the next block element" do
      nodes = parse_multi("{#id}\npara\n\n{.class}\n# Header\n\n{ref}\n* list", 5)
      assert_equal("id", nodes[0].attributes['id'])
      assert_equal("class", nodes[2].attributes['class'])
      assert_equal(["ref"], nodes[4].properties[:refs])
    end

    it "allows multiple attribute lists after another" do
      node = parse_single("{#id}  \t\v\n{.class}\npara", :paragraph, 1)
      assert_equal({"id" => "id", "class" => "class"}, node.attributes)
    end

    it "ignores an attribute list if it is not directly before an element" do
      nodes = parse_multi("{#id}\n\npara", 2)
      assert_nil(nodes[1].attributes)
    end

    it "ignores an attribute list if it cannot be parsed (e.g. due to trailing content)" do
      node = parse_single("{#id} trash\npara", :paragraph, 3)
      assert_equal("{#id} trash", node.children[0].content)
      assert_equal("para", node.children[2].content)
    end
  end

  describe "parse_attribute_list_content" do
    def assert_attribute_list(result, str)
      assert_equal(result, @parser.send(:parse_attribute_list_content, +str))
    end

    it "recognizes IDs" do
      assert_attribute_list({"id" => "id"}, "#id")
    end

    it "recognizes class names" do
      assert_attribute_list({"class" => "cls1 cls2"}, ".cls1 .cls2")
    end

    it "recognizes references" do
      assert_attribute_list({refs: ["ähm.cl#3", "om{}y"]}, "ähm.cl#3 om{}y")
    end

    it "removes escaped closing braces from references" do
      assert_attribute_list({refs: ["ref}here"]}, "ref\\}here")
    end

    it "recognizes key-value pairs without quoting" do
      assert_attribute_list({"key" => "value"}, "key=value")
    end

    it "recognizes key-value pairs with single quotes" do
      assert_attribute_list({"key" => "value"}, "key='value'")
    end

    it "recognizes key-value pairs with double quotes" do
      assert_attribute_list({"key" => "value"}, "key=\"value\"")
    end

    it "removes escaped closing braces from values of key-value pairs" do
      assert_attribute_list({"key" => "}pair"}, "key=\\}pair")
    end

    it "removes the escaped quote character from values of key-value pairs" do
      assert_attribute_list({"key" => "this'is"}, "key='this\\'is'")
    end

    it "ignores escaped characters except for the closing brace and quote character" do
      assert_attribute_list({"key" => "t\\his'is"}, "key='t\\his\\'is'")
    end

    it "doesn't allow unescaped closing braces in attribute names or values" do
      assert_attribute_list({refs: ['#id}a', '.cl}ass', 're}e', 'key=val}ue']},
                            "#id}a .cl}ass re}e key=val}ue")
    end

    it "works for empty strings" do
      assert_attribute_list({}, "")
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

    it "works for content marked-up with subscript" do
      node = parse_single("~home~", :paragraph, 1)
      assert_equal(:subscript, node.children[0].type)
    end

    it "works for content marked-up with superscript" do
      node = parse_single("^home^", :paragraph, 1)
      assert_equal(:superscript, node.children[0].type)
    end

    it "works inside of words" do
      node = parse_single("a*test*b", :paragraph, 3)
      assert_equal(:strong, node.children[1].type)
      assert_equal("a", node.children[0].content)
      assert_equal("b", node.children[2].content)
    end

    it "ignores closing markers when element has not been opened" do
      node = parse_single("a* test", :paragraph, 1)
      assert_equal("a* test", node.children[0].content)
    end

    it "ignores markers with whitespace around them" do
      node = parse_single("a * b*", :paragraph, 1)
      assert_equal("a * b*", node.children[0].content)
    end

    it "allows nesting of same-type elements" do
      node = parse_single("a*test *b* test*", :paragraph, 2)
      assert_equal(:strong, node.children[1].type)
      assert_equal("a", node.children[0].content)
      assert_equal("test ", node.children[1].children[0].content)
      assert_equal(:strong, node.children[1].children[1].type)
      assert_equal(" test", node.children[1].children[2].content)
    end

    it "works directly before continuation lines borders" do
      node = parse_single("*test*\n_hallo_", :paragraph, 3)
      assert_equal(:strong, node.children[0].type)
      assert_equal(:soft_break, node.children[1].type)
      assert_equal(:emphasis, node.children[2].type)
    end

    it "works across continuation lines" do
      node = parse_single("*test\rhallo*", :paragraph, 1)
      assert_equal(:strong, node.children[0].type)
      assert_equal("test", node.children[0].children[0].content)
      assert_equal(:soft_break, node.children[0].children[1].type)
      assert_equal("hallo", node.children[0].children[2].content)
    end

    it "handles unclosed nodes" do
      node = parse_single("_home *star_ *home _star*", :paragraph, 3)
      assert_equal(:emphasis, node.children[0].type)
      assert_equal(:text, node.children[1].type)
      assert_equal(:strong, node.children[2].type)
      assert_equal('home *star', node.children[0].children[0].content)
      assert_equal('home _star', node.children[2].children[0].content)
    end
  end

  describe "parse_backslash_escape" do
    it "handles the marker characters for simple inline markup" do
      node = parse_single("T~his\\~ \\*is _not\\_ m\\^ark^ed* \\`up`.", :paragraph, 1)
      assert_equal('T~his~ *is _not_ m^ark^ed* `up`.', node.children[0].content)
    end

    it "handles the marker characters for links" do
      node = parse_single("This \\[ is\\] not\\( a \\)drill", :paragraph, 1)
      assert_equal('This [ is] not( a )drill', node.children[0].content)
    end

    it "handles the marker characters for inline attribute lists" do
      node = parse_single("This \\{ is\\} a drill", :paragraph, 1)
      assert_equal('This { is} a drill', node.children[0].content)
    end

    it "handles the marker character for inline extensions" do
      node = parse_single("This \\:isnot: a drill", :paragraph, 1)
      assert_equal('This :isnot: a drill', node.children[0].content)
    end

    it "replaces an escaped line break with a hard line break element" do
      node = parse_single("This\\\nspace.\n", :paragraph, 3)
      assert_equal("This", node.children[0].content)
      assert_equal(:hard_break, node.children[1].type)
      assert_equal("space.", node.children[2].content)
    end

    it "replaces an escaped space with a non-breaking space" do
      node = parse_single("This\\ space.", :paragraph, 1)
      assert_equal("This\u00a0space.", node.children[0].content)
    end

    it "replaces an escaped backslash with a backslash" do
      node = parse_single("This\\\\ space.", :paragraph, 1)
      assert_equal("This\\ space.", node.children[0].content)
    end
  end

  describe "parse_verbatim" do
    it "works on a single line" do
      node = parse_single("Some `text` here", :paragraph, 3)
      assert_equal("Some ", node.children[0].content)
      assert_equal(:verbatim, node.children[1].type)
      assert_equal([], node.children[1].children)
      assert_equal("text", node.children[1].content)
      assert_equal(" here", node.children[2].content)
    end

    it "works on a single line with unclosed node" do
      node = parse_single("Some `text here", :paragraph, 1)
      assert_equal("Some `text here", node.children[0].content)
    end

    it "works on a single line containing inline-like markup" do
      node = parse_single("May *s `t* *data*` z", :paragraph, 3)
      assert_equal("May *s ", node.children[0].content)
      assert_equal(:verbatim, node.children[1].type)
      assert_equal([], node.children[1].children)
      assert_equal("t* *data*", node.children[1].content)
      assert_equal(" z", node.children[2].content)
    end

    it "works on a single line containing inline-like markup with unclosed node" do
      node = parse_single("May *s `t* *data* z", :paragraph, 3)
      assert_equal("May *s `t* ", node.children[0].content)
      assert_equal(:strong, node.children[1].type)
      assert_equal(" z", node.children[2].content)
    end

    it "works on multiple lines" do
      node = parse_single("Some `text *here\n  cont*inuing` here", :paragraph, 3)
      assert_equal(:verbatim, node.children[1].type)
      assert_equal([], node.children[1].children)
      assert_equal("text *here\ncont*inuing", node.children[1].content)
    end

    it "works on multiple lines with unclosed node" do
      node = parse_single("Some `text *here\n  cont*inuing here", :paragraph, 3)
      assert_equal("Some `text ", node.children[0].content)
      assert_equal(:strong, node.children[1].type)
      assert_equal("here", node.children[1].children[0].content)
      assert_equal(:soft_break, node.children[1].children[1].type)
      assert_equal("cont", node.children[1].children[2].content)
    end
  end

  describe "link" do
    it "works if the link content is across lines" do
      node = parse_single("Some [link\n  content](here) comes", :paragraph, 3)
      link = node.children[1]
      assert_equal(:link, link.type)
      assert_equal("link", link.children[0].content)
      assert_equal(:soft_break, link.children[1].type)
      assert_equal("content", link.children[2].content)
    end

    it "ignores right brackets that don't close the link content" do
      node = parse_single("Some [link] content](here) comes", :paragraph, 3)
      assert_equal(:link, node.children[1].type)
      assert_equal("link] content", node.children[1].children[0].content)
    end

    it "ignores right parentheses that don't close the inline link part" do
      node = parse_single("Some here) comes", :paragraph, 1)
      assert_equal("Some here) comes", node.children[0].content)
    end

    it "ignores the link if another inline markup closes within the link content" do
      node = parse_single("some *strong [argument*](here)", :paragraph, 3)
      assert_equal(:text, node.children[0].type)
      assert_equal(:strong, node.children[1].type)
      assert_equal(:text, node.children[2].type)
      assert_equal("strong [argument", node.children[1].children[0].content)
    end

    describe "inline" do
      it "works in the simple case" do
        node = parse_single("Some [link](here) comes", :paragraph, 3)
        assert_equal(:link, node.children[1].type)
        assert_equal("here", node.children[1][:destination])
        assert_equal("link", node.children[1].children[0].content)
      end

      it "works if the inline link is across lines" do
        node = parse_single("Some [link](here   \n   links) comes", :paragraph, 3)
        assert_equal(:link, node.children[1].type)
        assert_equal("herelinks", node.children[1][:destination])
      end

      it "handles a missing closing parentheses" do
        node = parse_single("Some [link](here comes", :paragraph, 1)
        assert_equal("Some [link](here comes", node.children[0].content)
      end

      it "prevents inline markup closing across the ]( border (like with verbatim)" do
        node = parse_single("Some [*link](here*", :paragraph, 1)
        assert_equal("Some [*link](here*", node.children[0].content)
      end
    end

    describe "reference" do
      it "works in the simple case" do
        node = parse_single("Some [link][here] comes", :paragraph, 3)
        assert_equal(:link, node.children[1].type)
        assert_equal("here", node.children[1][:reference])
        assert_equal("link", node.children[1].children[0].content)
      end

      it "works if the reference link name is across lines" do
        node = parse_single("Some [link][here  \n   ref] comes", :paragraph, 3)
        assert_equal(:link, node.children[1].type)
        assert_equal("hereref", node.children[1][:reference])
      end

      it "handles a missing closing parentheses" do
        node = parse_single("Some [link][here comes", :paragraph, 1)
        assert_equal("Some [link][here comes", node.children[0].content)
      end

      it "prevents inline markup closing across the ][ border (like with verbatim)" do
        node = parse_single("Some [*link][here*", :paragraph, 1)
        assert_equal("Some [*link][here*", node.children[0].content)
      end
    end
  end

  describe "inline attribute lists" do
    it "works after inline elements" do
      node = parse_single("Some *strong*{#id} element", :paragraph, 3)
      assert_equal(:strong, node.children[1].type)
      assert_equal("id", node.children[1].attributes['id'])
      assert_equal("Some ", node.children[0].content)
      assert_equal(" element", node.children[2].content)
    end

    it "extracts the :refs key and puts it into the node properties" do
      node = parse_single("Some *strong*{ref1 ref2} element", :paragraph, 3)
      assert_equal(0, node.children[1].attributes.size)
      assert_equal(['ref1', 'ref2'], node.children[1].properties[:refs])
    end

    it "multiple attribute lists can be used" do
      node = parse_single("Some *strong*{#id}{.class} element", :paragraph, 3)
      assert_equal({'id' => "id", 'class' => 'class'}, node.children[1].attributes)
    end

    it "ignores the nested inline attribute lists" do
      node = parse_single("Some *strong*{#id element", :paragraph, 3)
      assert_equal("{#id element", node.children[2].content)
    end

    it "ignores the inline attribute list if not closed" do
      node = parse_single("Some *strong*{#id element", :paragraph, 3)
      assert_equal("{#id element", node.children[2].content)
    end

    it "ignores the opening marker if not directly preceeded by an element" do
      node = parse_single("Some _*strong* {#id_} element", :paragraph, 3)
      assert_equal(:emphasis, node.children[1].type)
      assert_equal(" {#id", node.children[1].children[1].content)
    end

    it "prevents inline markup closing across the { marker (like verbatim)" do
      node = parse_single("Some _*strong*{#id_ element", :paragraph, 3)
      assert_equal("Some _", node.children[0].content)
      assert_equal("{#id_ element", node.children[2].content)
    end
  end

  describe "span" do
    it "it needs a bracketed content with an IAL" do
      node = parse_single("Some [span]{#id} element", :paragraph, 3)
      assert_equal(:span, node.children[1].type)
      assert_equal("id", node.children[1].attributes['id'])
      assert_equal("Some ", node.children[0].content)
      assert_equal(" element", node.children[2].content)
    end

    it "ignores the span if the IAL is not closed" do
      node = parse_single("Some [span]{#id element", :paragraph, 1)
      assert_equal("Some [span]{#id element", node.children[0].content)
    end

    it "ignores the span-closing/IAL-openeing marker if no span-opening marker was before" do
      node = parse_single("Some span]{#id element", :paragraph, 1)
      assert_equal("Some span]{#id element", node.children[0].content)
    end

    it "prevents inline markup closing across the ]{ marker (like verbatim)" do
      node = parse_single("Some [*strong]{#id* element", :paragraph, 1)
      assert_equal("Some [*strong]{#id* element", node.children[0].content)
    end
  end

  describe "inline extension" do
    it "can just be the extension name" do
      node = parse_single("Some :extension: name", :paragraph, 3)
      assert_equal(:inline_extension, node.children[1].type)
    end

    it "can have some markup content" do
      node = parse_single("Some :extension:[with *strong* content] here", :paragraph, 3)
      assert_equal(:inline_extension, node.children[1].type)
      assert_equal(:strong, node.children[1].children[1].type)
    end

    it "can have some verbatim content" do
      node = parse_single("Some :extension:(with *no strong* content) here", :paragraph, 3)
      assert_equal(:inline_extension, node.children[1].type)
      assert_equal('with *no strong* content', node.children[1][:data])
    end

    it "can use an attribute list" do
      node = parse_single("Some :extension:{#id} here", :paragraph, 3)
      assert_equal(:inline_extension, node.children[1].type)
      assert_equal('id', node.children[1].attributes['id'])
    end

    it "can have some markup content and verbatim content" do
      node = parse_single("Some :extension:[with *strong* content](*verbatim*) here", :paragraph, 3)
      assert_equal(:inline_extension, node.children[1].type)
      assert_equal(:strong, node.children[1].children[1].type)
      assert_equal('*verbatim*', node.children[1][:data])
    end

    it "can have some markup content and an attribute list" do
      node = parse_single("Some :extension:[with *strong* content]{#id} here", :paragraph, 3)
      assert_equal(:inline_extension, node.children[1].type)
      assert_equal(:strong, node.children[1].children[1].type)
      assert_equal('id', node.children[1].attributes['id'])
    end

    it "can have verbatim content and an attribute list" do
      node = parse_single("Some :extension:(*verbatim*){#id} here", :paragraph, 3)
      assert_equal(:inline_extension, node.children[1].type)
      assert_equal('*verbatim*', node.children[1][:data])
      assert_equal('id', node.children[1].attributes['id'])
    end

    it "can have some markup content, verbatim content and an attribute list" do
      node = parse_single("Some :extension:[with *strong* content](*verbatim*){#id} here", :paragraph, 3)
      assert_equal(:inline_extension, node.children[1].type)
      assert_equal(:strong, node.children[1].children[1].type)
      assert_equal('*verbatim*', node.children[1][:data])
      assert_equal('id', node.children[1].attributes['id'])
    end

    it "ignores the inline extension if the trailing colon is missing" do
      node = parse_single("no :extension", :paragraph, 1)
      assert_equal("no :extension", node.children[0].content)
    end

    it "ignores the inline extension if the name contains invalid characters" do
      node = parse_single("no :extensiön:", :paragraph, 1)
      assert_equal("no :extensiön:", node.children[0].content)
    end

    it "ignores the inline extension if the markup content is not closed" do
      node = parse_single("no :extension:[here to see", :paragraph, 1)
      assert_equal("no :extension:[here to see", node.children[0].content)
    end

    it "ignores the inline extension if the attribute list is not closed" do
      node = parse_single("no :extension:{here to see", :paragraph, 1)
      assert_equal("no :extension:{here to see", node.children[0].content)
    end

    it "prevents inline markup closing across the verbatim content marker" do
      node = parse_single("Some *strong :extension:(here* element", :paragraph, 1)
      assert_equal("Some *strong :extension:(here* element", node.children[0].content)
    end
  end
end
