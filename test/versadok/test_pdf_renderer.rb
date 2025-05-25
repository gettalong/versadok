require 'test_helper'
require 'versadok/pdf_renderer'
require 'versadok/context'
require 'versadok/node'
require 'versadok/parser'
require 'hexapdf/test_utils'

describe VersaDok::PDFRenderer do
  def node(type, children: nil, attr: nil, content: nil, **properties)
    VersaDok::Node.new(type, content: content, attributes: attr, properties: properties).tap do |n|
      n.children.replace(children) if children
    end
  end

  def render(type, children: nil, attr: nil, content: nil, **properties)
    @renderer.render(node(type, children: children, content: content, attr: attr, **properties),
                     layout: @composer.document.layout)
  end

  before do
    @context = VersaDok::Context.new
    @renderer = VersaDok::PDFRenderer.new(@context)
    @composer = HexaPDF::Composer.new
  end

  describe "render" do
    it "creates a HexaPDF::Composer object if the layout argument is not provided" do
      composer = @renderer.render(node(:root, children: [
                                         node(:paragraph, children: [node(:text, content: 'Test')])]))
      assert_kind_of(HexaPDF::Composer, composer)
      assert_equal([0, 0, 595, 841], composer.document.pages[0].box(:media).value.map(&:to_i))
      assert(composer.style?(:header2))
    end

    it "renders a simple document" do
      doc = <<~EOF
      test1

      test2

      > test1
      >
      > test2
      EOF
      result = @renderer.render(VersaDok::Parser.new(@context).parse(doc).finish,
                                layout: @composer.document.layout)
      assert_equal(3, result.size)
    end
  end

  describe "block_style" do
    it "allows specifiying nested styles" do
      @composer.style(:blockquote_paragraph, font_size: 50)
      box = render(:blockquote, children: [node(:paragraph)])
      assert_equal(50, box.children[0].style.font_size)
    end
  end

  describe "render_paragraph" do
    it "uses a TextBox with style :paragraph" do
      @composer.style(:paragraph, font_size: 50)
      box = render(:paragraph)
      assert_kind_of(HexaPDF::Layout::TextBox, box)
      assert_equal(50, box.style.font_size)
    end

    it "renders the children" do
      box = render(:paragraph, children: [node(:text, content: "Test")])
      items = box.instance_variable_get(:@items)
      assert_equal(1, items.size)
      assert_equal("Test", box.text)
    end
  end

  describe "render_header" do
    it "uses a TextBox with style :headerLEVEL" do
      @composer.style(:header2, font_size: 50)
      box = render(:header, level: 2)
      assert_kind_of(HexaPDF::Layout::TextBox, box)
      assert_equal(50, box.style.font_size)
    end

    it "renders the children" do
      @composer.style(:header2_text, font_size: 50)
      box = render(:header, level: 2, children: [node(:text, content: "Test")])
      items = box.instance_variable_get(:@items)
      assert_equal(1, items.size)
      assert_equal(50, items[0].style.font_size)
    end
  end

  describe "render_blockquote" do
    it "uses a splitable ContainerBox with style :blockquote" do
      @composer.style(:blockquote, margin: 20)
      box = render(:blockquote)
      assert_kind_of(HexaPDF::Layout::ContainerBox, box)
      assert(box.splitable)
      assert_equal(20, box.style.margin.top)
    end

    it "renders the children" do
      box = render(:blockquote, children: [node(:paragraph, children: [node(:text, content: "Test")])])
      assert_equal(1, box.children.size)
      assert_equal("Test", box.children[0].text)
    end
  end

  describe "render_list" do
    it "uses a ListBox with an appropriate style like :list_asterisk" do
      @composer.style(:list_asterisk, margin: 20)
      box = render(:list, marker: :asterisk)
      assert_kind_of(HexaPDF::Layout::ListBox, box)
      assert_equal(20, box.style.margin.top)
      assert_equal(1, box.start_number)
    end

    it "works for ordered lists" do
      box = render(:list, start: 3, marker: :decimal)
      assert_kind_of(HexaPDF::Layout::ListBox, box)
      assert_equal(3, box.start_number)
    end

    it "renders the children" do
      item1 = node(:list_item, children: [node(:paragraph, children: [node(:text, content: "Test1")])])
      item2 = node(:list_item, children: [node(:paragraph, children: [node(:text, content: "Test2")])])
      box = render(:list, children: [item1, item2])
      assert_equal(2, box.children.size)
      assert_equal(1, box.children[0].size)
      assert_equal("Test1", box.children[0][0].text)
      assert_equal(1, box.children[1].size)
      assert_equal("Test2", box.children[1][0].text)
    end
  end

  describe "render_code_block" do
    it "uses a TextBox with style :code_block" do
      @composer.style(:code_block, font_size: 50)
      box = render(:code_block, content: '')
      assert_kind_of(HexaPDF::Layout::TextBox, box)
      assert_equal(50, box.style.font_size)
    end
  end

  describe "text_style" do
    def check_style(**style_names)
      box = render(
        :blockquote,
        children: [
          node(:paragraph,
               children: [node(:strong,
                               children: [node(:emphasis, children: [node(:text, content: "Test")])])])
        ])
      style = box.children[0].instance_variable_get(:@items)[0].style
      style_names.each {|name, value| assert_equal(value, style.send(name)) }
    end

    it "uses the fully nested style name if defined" do
      @composer.style(:blockquote_paragraph_strong_emphasis_text, font_size: 50)
      check_style(font_size: 50)
    end

    it "adds the _text suffix to the fully nested style name if requested" do
      @composer.style(:code_block_text, font_size: 50)
      box = render(:code_block, content: '')
      assert_equal(50, box.instance_variable_get(:@items)[0].style.font_size)
    end

    it "uses the nested block style name if the fully nested style name is not defined" do
      @composer.style(:blockquote_paragraph_text, font_size: 50)
      check_style(font_size: 50)
    end

    it "uses the inner-most block node type if a more specific name is not defined" do
      @composer.style(:paragraph_text, font_size: 50)
      check_style(font_size: 50)
    end

    it "falls back to the :base_text style name if no block-level style name is defined" do
      @composer.style(:base_text, font_size: 50)
      check_style(font_size: 50)
    end

    it "merges inline styles of nested nodes" do
      @composer.style(:strong, font_size: 30, font_bold: true)
      @composer.style(:emphasis, font_size: 20)
      @composer.style(:base_text, font_size: 50, font_italic: true)
      check_style(font_size: 20, font_bold: true, font_italic: true)
    end

    it "caches a created style for re-use" do
      @composer.style(:paragraph_text, font_size: 50)
      check_style(font_size: 50)
      @composer.style(:paragraph_text, font_size: 100)
      check_style(font_size: 50)
    end

    it "duplicates the resulting style if overrides are used" do
      @composer.style(:paragraph_link_text, font_size: 50)
      ['dest1.html', 'dest2.html'].each do |destination|
        box = render(:paragraph, children: [node(:link, destination: destination, children: [
                                                   node(:text, content: "Test")])])
        assert_equal(50, box.instance_variable_get(:@items)[0].style.font_size)
        assert_equal([[:link, {uri: destination}]],
                     box.instance_variable_get(:@items)[0].style.overlays.layers)
      end
    end
  end

  describe "render_text" do
    it "returns a hash with an appropriate style" do
      @composer.style(:base_text, font_size: 20)
      hash = render(:text, content: "Test")
      assert_equal("Test", hash[:text])
      assert_equal(20, hash[:style].font_size)
    end
  end

  describe "soft_break" do
    it "returns a space character" do
      assert_equal(' ', render(:soft_break))
    end
  end

  describe "hard_break" do
    it "returns a line feed character" do
      assert_equal("\n", render(:hard_break))
    end
  end

  describe "render_verbatim" do
    it "returns a hash with an appropriate style" do
      @composer.style(:verbatim, font_size: 20)
      hash = render(:verbatim, content: "Test")
      assert_equal("Test", hash[:text])
      assert_equal(20, hash[:style].font_size)
    end
  end

  describe "render_link" do
    it "applies a style override for inline links" do
      result = render(:link, destination: 'dest.html', children: [node(:text, content: 'Test')])
      assert_equal(1, result.size)
      assert_equal("Test", result[0][:text])
      assert_equal([[:link, {uri: 'dest.html'}]], result[0][:style].overlays.layers)
    end

    it "applies a style override for existing reference links" do
      @context.link_destinations['ref'] = 'dest.html'
      result = render(:link, reference: 'ref', children: [node(:text, content: 'Test')])
      assert_equal(1, result.size)
      assert_equal("Test", result[0][:text])
      assert_equal([[:link, {uri: 'dest.html'}]], result[0][:style].overlays.layers)
    end

    it "does nothing for unknown reference links" do
      result = render(:link, reference: 'ref', children: [node(:text, content: 'Test')])
      assert_equal(1, result.size)
      assert_equal("Test", result[0][:text])
      assert_equal([], result[0][:style].each_property.to_a)
    end
  end
end
