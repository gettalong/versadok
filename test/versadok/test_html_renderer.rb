require 'test_helper'
require 'versadok/html_renderer'
require 'versadok/node'

describe VersaDok::HTMLRenderer do
  def node(type, children: nil, attr: nil, content: nil, **properties)
    VersaDok::Node.new(type, content: content, attributes: attr, properties: properties).tap do |n|
      n.children.replace(children) if children
    end
  end

  def render(type, children: nil, attr: nil, content: nil, **properties)
    @renderer.render(node(type, children: children, content: content, attr: attr, **properties))
  end

  before do
    @renderer = VersaDok::HTMLRenderer.new
    @simple_para = node(:paragraph, children: [node(:text, content: 'Simple paragraph')])
  end

  describe "html_attributes" do
    it "renders simples attributes" do
      assert_equal("<p class=\"class\" id=\"id\"></p>\n",
                   render(:paragraph, attr: {'class' => 'class', 'id' => 'id'}))
    end

    it "renders attributes that need escapes" do
      assert_equal("<p class=\"cl&quot;a&lt;s&gt;s\" id=\"i&amp;d\"></p>\n",
                   render(:paragraph, attr: {'class' => 'cl"a<s>s', 'id' => 'i&d'}))
    end

    it "doesn't render attributes if they are nil or empty" do
      assert_equal("<p></p>\n", render(:paragraph, attr: nil))
      assert_equal("<p></p>\n", render(:paragraph, attr: {}))
    end

    it "doesn't render key-value pairs if the value is nil" do
      assert_equal("<p></p>\n", render(:paragraph, attr: {'key' => nil}))
    end

    it "doesn't render the :refs key" do
      assert_equal("<p></p>\n", render(:paragraph, attr: {refs: 'test'}))
    end

    it "doesn't render the id key if the value is empty" do
      assert_equal("<p></p>\n", render(:paragraph, attr: {'id' => ''}))
    end

    it "doesn't render a value twice if additionally specified with an override" do
      assert_equal("<ol start=\"3\">\n</ol>\n",
                   render(:list, marker: :decimal, start: 3, attr: {'start' => 5}))
    end
  end

  describe "render_paragraph" do
    it "renders a simple paragraph" do
      assert_equal("<p>Simple paragraph</p>\n",
                   render(:paragraph, children: [node(:text, content: 'Simple paragraph')]))
    end

    it "renders attributes" do
      assert_equal("<p class=\"class\">Simple paragraph</p>\n",
                   render(:paragraph, attr: {'class' => 'class'},
                          children: [node(:text, content: 'Simple paragraph')]))
    end

    it "renders an empty paragraph" do
      assert_equal("<p></p>\n", render(:paragraph))
    end
  end

  describe "render_header" do
    it "renders a simple header" do
      assert_equal("<h1>Simple</h1>\n",
                   render(:header, level: 1, children: [node(:text, content: 'Simple')]))
    end

    it "renders attributes" do
      assert_equal("<h1 class=\"class\">Simple</h1>\n",
                   render(:header, level: 1, attr: {'class' => 'class'},
                          children: [node(:text, content: 'Simple')]))
    end

    it "renders an empty header" do
      assert_equal("<h1></h1>\n", render(:header, level: 1))
    end

    it "renders all header levels" do
      assert_equal("<h2></h2>\n", render(:header, level: 2))
      assert_equal("<h3></h3>\n", render(:header, level: 3))
      assert_equal("<h4></h4>\n", render(:header, level: 4))
      assert_equal("<h5></h5>\n", render(:header, level: 5))
      assert_equal("<h6></h6>\n", render(:header, level: 6))
    end

    it "renders invalid header levels as h6" do
      assert_equal("<h6></h6>\n", render(:header, level: 7))
    end
  end

  describe "render_blockquote" do
    it "renders a simple blockquote" do
      assert_equal("<blockquote>\n<p>Simple paragraph</p>\n</blockquote>\n",
                   render(:blockquote,
                          children: [@simple_para]))
    end

    it "renders attributes" do
      assert_equal("<blockquote class=\"class\">\n<p>Simple paragraph</p>\n</blockquote>\n",
                   render(:blockquote, attr: {'class' => 'class'},
                          children: [@simple_para]))
    end

    it "renders an empty blockquote" do
      assert_equal("<blockquote>\n</blockquote>\n", render(:blockquote))
    end
  end

  describe "render_list" do
    before do
      @list_item = node(:list_item, children: [@simple_para])
    end

    it "renders a simple list" do
      assert_equal("<ul>\n<li>\n<p>Simple paragraph</p>\n</li>\n" \
                   "<li>\n<p>Simple paragraph</p>\n</li>\n</ul>\n",
                   render(:list, children: [@list_item, @list_item]))
    end

    it "renders attributes" do
      assert_equal("<ul class=\"class\">\n<li>\n<p>Simple paragraph</p>\n</li>\n</ul>\n",
                   render(:list, attr: {'class' => 'class'}, children: [@list_item]))
    end

    it "renders an empty list" do
      assert_equal("<ul>\n</ul>\n", render(:list))
    end

    it "renders an ordered list" do
      assert_equal("<ol>\n<li>\n<p>Simple paragraph</p>\n</li>\n</ol>\n",
                   render(:list, marker: :decimal, children: [@list_item]))
    end

    it "renders an ordered list with a start number" do
      assert_equal("<ol start=\"5\">\n<li>\n<p>Simple paragraph</p>\n</li>\n</ol>\n",
                   render(:list, marker: :decimal, start: 5, children: [@list_item]))
    end
  end

  describe "render_text" do
    it "escapes special HTML characters" do
      assert_equal("This &lt;is&gt; some &quot;list&quot; &amp;here",
                   render(:text, content: 'This <is> some "list" &here'))
    end
  end

  describe "render_soft_break" do
    it "renders a soft line break as a simple line break" do
      assert_equal("\n", render(:soft_break))
    end
  end

  describe "render_hard_break" do
    it "renders a hard line break as a <br /> tag with a line break" do
      assert_equal("<br />\n", render(:hard_break))
    end
  end

  describe "render_verbatim" do
    it "renders as <code> tag" do
      assert_equal("<code>This &lt;is&gt; verbatim</code>",
                   render(:verbatim, content: 'This <is> verbatim'))
    end
  end

  describe "render_strong" do
    it "renders as <strong> tag" do
      assert_equal("<strong>strong content</strong>",
                   render(:strong, children: [node(:text, content: 'strong content')]))
    end
  end

  describe "render_emphasis" do
    it "renders as <em> tag" do
      assert_equal("<em>emphasis content</em>",
                   render(:emphasis, children: [node(:text, content: 'emphasis content')]))
    end
  end

  describe "render_superscript" do
    it "renders as <sup> tag" do
      assert_equal("<sup>superscript content</sup>",
                   render(:superscript, children: [node(:text, content: 'superscript content')]))
    end
  end

  describe "render_subscript" do
    it "renders as <sup> tag" do
      assert_equal("<sub>subscript content</sub>",
                   render(:subscript, children: [node(:text, content: 'subscript content')]))
    end
  end

  describe "render_link" do
    it "renders a link with a destination" do
      assert_equal("<a href=\"target.html\">link content</a>",
                   render(:link, destination: 'target.html',
                          children: [node(:text, content: 'link content')]))
    end

    it "renders a link with a reference" do
      assert_equal("<a>link content</a>",
                   render(:link, reference: 'refspec',
                          children: [node(:text, content: 'link content')]))
      skip #TODO
    end
  end
end
