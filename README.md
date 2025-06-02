# VersaDok

VersaDok is a lightweight markup language. Its design is mainly based on [kramdown], a
Markdown-superset, and on [Djot], with further influence from [AsciiDoc] and [reStructuredText].

The goal of VersaDok is to create a markup language that is easy to write, read and reason about. It
should be fully-featured and not tied to a particular output format. By making it Markdown-like many
people will already be familiar with the general syntax.

The syntax of the language is not yet finalized and may change. Some syntax elements are still
missing. Suggestions and feedback are best reported via the [issue tracker][issues].

[kramdown]: https://kramdown.gettalong.org
[Djot]: https://djot.net
[AsciiDoc]: https://docs.asciidoctor.org/asciidoc/latest/
[reStructuredText]: https://docutils.sourceforge.io/rst.html
[issues]: https://github.com/gettalong/versadok/issues


## Syntax cheat sheet

The full syntax documentation can be found in [`website/syntax.page`](website/syntax.page).

### Block elements

* Paragraph

  ~~~
  This is just some text that gets
  transformed into a paragraph.
  ~~~

* Header

  ~~~
  # Headers like in Markdown
  but also lazy wrapped
  ~~~

* Blockquote

  ~~~
  > Blockquotes are created like
  in Markdown.
  ~~~

* Ordered and unordered list

  ~~~
  1. This is an
  2. Ordered list.

  * While this list
  * has no ordering
  ~~~

* Code block

  ~~~~~
  ~~~
  Code blocks are put between lines of
  tilde characters.
  ~~~
  ~~~~~

* General block

  ~~~
  <<< .information
  A general block is just a container for
  block elements. It can contain an attribute
  list on the starting line.
  >>>
  ~~~

* Block extension

  ~~~
  ::extension: key=value #id
    A named block extension allows extending the functionality.
    The indented content can either be parsed as block elements
    or by the extension itself.
  ~~~

* Reference link definition

  ~~~
  [linkdef]: http://example.com
  ~~~

* Attribute list

  ~~~
  {#id .class key=value}
  The attribute list can be used to assign attributes to any
  block element.
  ~~~


### Inline elements

* Strong

  ~~~
  This a *strong* suggestion.
  ~~~

* Emphasis

  ~~~
  The _emphasis_ is on the first letter.
  ~~~

* Superscript

  ~~~
  This goes ^high^ up into the air.
  ~~~

* Subscript

  ~~~
  Who said something ~down~ deep?
  ~~~

* Verbatim

  ~~~
  Some things are taken `as is`.
  ~~~

* Link

  ~~~
  We can [link](https://example.com) everything.
  And [to][def] everything.

  [def]: https://example.com
  ~~~

* Autolink

  ~~~
  It's easier to write <https://example.com> than
  to write it as a normal link.
  ~~~

* Image

  ~~~
  Embedding ![images](images.png) was never easier.
  ~~~

* Inline attribute list

  ~~~
  As with block elements, inline elements
  like *this*{.class} can be assigned attributes.
  ~~~

* Span

  ~~~
  The [span]{.highlight} element can be used to mark up
  any part of the text and assign attributes.
  ~~~

* Line break

  ~~~
  As with Markdown, normal line breaks are treated
  as soft line breaks. A hard line break needs a \
  backslash before the line separator.
  ~~~

* Inline extension

  ~~~
  An :inline: extension can be used like a block extension
  to :extend:[the functionality]. It can consist of just
  the name but also has parts for content and :data:(data)
  which may be :combined:[like this](data here).
  ~~~

## License

MIT - see the LICENSE file for licensing details.
