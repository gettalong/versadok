# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of VersaDok.
#
# VersaDok - Versatile document creation markup and library
# Copyright (C) 2025 Thomas Leitner <t_leitner@gmx.at>
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'strscan'
require_relative 'node'
require_relative 'extension'
require_relative 'context'

module VersaDok

  class Parser

    # The Stack holds the parsing context.
    #
    # == How the stack works
    #
    # Initially there is one node in the stack, the one given on initialization. This is usually the
    # :root node. The current level, i.e. the index into the stack array, points to this container
    # node.
    #
    # Every time a new *container* element is encountered, it is added to the stack at the correct
    # place and the current level is appropriately adjusted. This place is either as the inner-most
    # element (think parsing a strong element inside a paragraph) or at a higher level (think
    # parsing a paragraph after a blockquote).
    #
    # As parsing is done line by line it is possible that the inner-most element is not yet
    # closed. Here is an example document:
    #
    #   > This is a *strong
    #   > paragraph*.
    #
    # After parsing the first line the stack looks like this:
    #
    #   root -> blockquote -> paragraph -> [strong]
    #
    # The strong element is the current container element with the current level pointing to
    # it. Then when the next line is parsed, the stack looks initially like this:
    #
    #   [root] -> blockquote -> paragraph -> strong
    #
    # The parser then enters the elements in the stack while parsing. For example, it encounters the
    # '>' marker and enters the blockquote element, adjusting the current level:
    #
    #   root -> [blockquote] -> paragraph -> strong
    #
    # Then the paragraph continuation line is parsed:
    #
    #   root -> blockquote -> paragraph -> [strong]
    #
    # As the strong element was the last element on the last line, the parser continues with it as
    # the current element. Once it finds the closing marker, the element is closed and removed from
    # the stack:
    #
    #   root -> blockquote -> [paragraph]
    #
    # The stack supports methods for adding, entering, closing and removing nodes as well as other
    # needed methods.
    class Stack

      # Creates a new Stack instance with +node+ as the base node.
      def initialize(node)
        @stack = [node]
        @level = 0
      end

      # Returns the current container element.
      #
      # Note that this can be any element on the stack depending on the current parsing state.
      def container
        @stack[@level]
      end

      # Returns +true+ if the current state of the stack represents being at a block boundary.
      #
      # A block boundary exists if the stack is currently at the start of a level or the last child
      # element of the inner-most element is :blank.
      #
      # Note that this method is only useful during block parsing.
      def block_boundary?
        @level + 1 == @stack.size || @stack[-1].children.last&.type == :blank
      end

      # Returns the last child of the current #container element.
      def last_child
        @stack[@level].children.last
      end

      # Returns the element at the given stack +level+.
      def [](level)
        @stack[level]
      end

      # Returns the stack level of the inner-most element of the given +type+ or +nil+ if no such
      # element is on the stack.
      #
      # Note that this method stops searching at :verbatim elements.
      def node_level(type)
        @stack.rindex do |n|
          break if type != n.type && n.content_model == :verbatim
          n.type == type
        end
      end

      # Closes the element at the given +level+ by removing it from the stack.
      #
      # All unclosed inline elements below the given level are deleted and their start marker
      # treated as plain text.
      def close_node(level)
        (@stack.size - 1).downto(level + 1) do |i|
          break if @stack[i].category != :inline
          children = @stack[i - 1].children
          node = children.delete_at(-1)
          if children.last&.type == :text
            children.last.content << node[:marker].to_s
          else
            children << Node.new(:text, content: +node[:marker].to_s)
          end
          if node.children.first&.type == :text
            children.last.content << node.children.first.content
            children.concat(node.children[1..-1])
          else
            children.concat(node.children)
          end
        end
        @stack.pop(@stack.size - level)
        @level = level - 1
      end

      # Removes the node at the given +level+ from the stack and from its parent node and returns
      # it.
      def remove_node(level)
        node = @stack[level]
        @stack[level - 1].children.delete(node)
        @stack.pop(@stack.size - level)
        @level = level - 1
        node
      end

      # Iterates in reverse order (from inner-most to outer-most) over all inline nodes having a
      # verbatim content model and yields them.
      def each_inline_verbatim
        return to_enum(__method__) unless block_given?
        @stack.reverse_each do |node|
          break if node.category == :block
          yield(node) if node.content_model == :verbatim
        end
      end

      # Resets the current level of the stack to the given +level+.
      def reset_level(level = 0)
        @level = (@stack.size + level) % @stack.size
      end

      # Enters the last child of the current container element by increasing the current level.
      #
      # Note that this method doesn't check whether the last child is actually on the stack.
      def enter
        @level += 1
      end

      # Enters the inner-most node in the stack that has an indentation smaller or equal to
      # +indent+ by setting the current level appropriately.
      def enter_indented(indent)
        @temp = @level + 1
        while @temp < @stack.size && (el_indent = @stack[@temp][:indent]) && el_indent <= indent
          @level = @temp if el_indent > 0
          @temp += 1
        end
      end

      # Appends the given +node+ as child of the current container element.
      #
      # If +container+ is +true+, the node will be added to the stack and made the current container
      # element by adjusting the current level.
      #
      # Note that the last child of the current container will also be closed (see #close_node).
      def append_child(node, container: true)
        close_node(@level + 1) unless @level + 1 == @stack.size
        @stack.last << node
        if container
          @stack << node
          @level += 1
        end
      end

      # Returns a simple string representation of the stack in the form of
      #
      #   root -> node_type -> [current_node_type] -> another_node_type
      def to_s
        @stack.map.with_index {|n, i| @level == i ? "[#{n.type}]" : n.type }.join(' -> ')
      end

    end

    # The parsing context (see Context).
    attr_reader :context

    # Creates a new Parser instance with the given +context+.
    def initialize(context)
      @context = context
      @scanner = StringScanner.new(''.b)
      @stack = Stack.new(Node.new(:root))
      @attribute_list = nil
      @line_no = 1
    end

    # Parses the given string +str+ which is assumed to contain one or more complete lines.
    #
    # This method may be called multiple times. After the last time #finish must be called.
    def parse(str)
      @scanner.string = str
      until @scanner.eos?
        @stack.reset_level
        parse_line
      end
      self
    end

    # Ensures that the parsing state is valid and represents the parsed lines. Returns the root node
    # containing the result.
    def finish
      @stack.close_node(1)
      @stack[0]
    end

    private

    # All possible line endings plus EOS
    EOL_RE_STR = "\\r\\n?|\\n|\\z"

    # The single :blank node.
    BLANK_NODE = Node.new(:blank)

    # Parses a single line for block elements.
    #
    # This method may be called multiple times for the same source line in case of nested
    # elements. For example, the source line
    #
    #   > * list item
    #
    # will lead to three calls of this method: The initial call with all of the line, then for the
    # part inside the blockquote and finally for the content of the list item.
    #
    # See #parse_continuation_line for the main inline parsing method.
    def parse_line
      @scanner.skip(/[ \t\v]*/)
      @current_indent = @scanner.matched_size

      @stack.enter_indented(@current_indent) if @current_indent > 0

      case (byte = @scanner.peek_byte)
      when 35 # #
        parse_header
      when 62 # >
        parse_blockquote
      when 42, 43, 45, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57 # * + - 0-9
        parse_list_item(byte)
      when 58 # :
        parse_extension_block
      when 123 # {
        parse_attribute_list
      when 13, 10, nil # \r \n EOS
        byte = @scanner.scan_byte
        @scanner.scan_byte if byte == 13 && @scanner.peek_byte == 10
        @stack.enter_indented(1000)
        unless @stack.last_child&.type == :blank
          @stack.append_child(BLANK_NODE, container: false)
        end
        @attribute_list = nil
        @line_no += 1
      else
        parse_continuation_line
      end
    end

    # Parses the header element at the current position.
    def parse_header
      if @scanner.scan(/\#{1,6} /)
        level = @scanner.matched_size - 1
        if @stack.block_boundary?
          @stack.append_child(block_node(:header, properties: {level: level}))
        elsif @stack.last_child.type != :header || @stack.last_child[:level] != level
          @scanner.unscan
        end
      end
      parse_continuation_line
    end

    # Parses the blockquote element at the current position.
    def parse_blockquote
      if @scanner.match?("> ")
        if @stack.last_child&.type == :blockquote
          @scanner.pos += 2
          @stack.enter
          parse_line
        elsif @stack.block_boundary?
          @scanner.pos += 2
          @stack.append_child(block_node(:blockquote))
          parse_line
        else
          parse_continuation_line
        end
      elsif @scanner.match?(/>(?:#{EOL_RE_STR})/o)
        if @stack.last_child&.type == :blockquote
          @scanner.pos += @scanner.matched_size
          @stack.enter
          @stack.enter_indented(1000)
          unless @stack.last_child.type == :blank
            @stack.append_child(BLANK_NODE, container: false)
          end
          @attribute_list = nil
        else
          parse_continuation_line
        end
        @line_no += 1
      else
        parse_continuation_line
      end
    end

    # Maps character codes to list item marker names.
    MARKER_MAP = {
      42 => :asterisk,
      43 => :plus,
      45 => :minus,
    }
    (48..57).each {|byte| MARKER_MAP[byte] = :decimal }

    # Parses the list item at the current position.
    #
    # The +byte+ argument is the character code of the first byte of the list item marker.
    def parse_list_item(byte)
      if @scanner.match?(/[*+-] |(\d+)([.)]) /)
        marker = MARKER_MAP[byte]
        last_child = @stack.last_child
        if last_child&.type == :list && last_child[:marker] == marker &&
           last_child.children.last[:indent] >= @current_indent
          @stack.enter
        elsif @stack.block_boundary?
          properties = {indent: 0, marker: marker}
          properties[:start] = @scanner[1].to_i if marker == :decimal
          @stack.append_child(block_node(:list, properties: properties))
        else
          parse_continuation_line
          return
        end
        @scanner.pos += @scanner.matched_size
        @stack.append_child(Node.new(:list_item, properties: {indent: @current_indent + 1}))
        parse_line
      else
        parse_continuation_line
      end
    end

    # Parses the extension block element at the current position.
    def parse_extension_block
      if @scanner.match?(/::(\w+):(?= |#{EOL_RE_STR})/o) && @stack.block_boundary?
        name = @scanner[1]
        extension = @context.extension(name)
        @scanner.pos += @scanner.matched_size
        attrs = parse_attribute_list_content(@scanner.scan_until(/#{EOL_RE_STR}/o), @attribute_list || {})
        parse_content = extension.parse_content?

        indent = @current_indent + 1
        indent = [indent, attrs.delete("indent")&.to_i || indent + 1].max if parse_content
        properties = {name: name, indent: indent, refs: attrs.delete(:refs)}
        properties[:content_model] = (parse_content ? :special : :block)
        @stack.append_child(Node.new(:extension_block, properties: properties, attributes: attrs),
                            container: !parse_content)

        if parse_content
          re = /[ \t\v]{#{indent}}|[ \t\v]{0,#{indent - 1}}(?=#{EOL_RE_STR})/
          while !@scanner.eos? && @scanner.scan(re)
            extension.parse_line(@scanner.scan_until(/#{EOL_RE_STR}/o))
          end
          extension.parsing_finished!
        end
      else
        parse_continuation_line
      end
    end

    # Parses the attribute list at the current position.
    def parse_attribute_list
      if @scanner.scan(/\{(#{AL_ANY_CHARS}+)\}[ \t\v]*(?:#{EOL_RE_STR})/o) && @stack.block_boundary?
        parse_attribute_list_content(@scanner[1], @attribute_list ||= {})
      else
        parse_continuation_line
      end
    end

    # The regular expression for matching an inline element.
    INLINE_RE = /(?=
                   \\[*_~^`\[\]\(\)\{\}:\r\n \\] # Match backslash escapes
                   |[*_~^`\[\]\)\{\}:]           # Match inline element start or end
                   |#{EOL_RE_STR})               # Match end of line
                /ox

    # Maps all whitespace character codes to +true+.
    WHITESPACE_LUT = {9 => true, 10 => true, 11 => true, 13 => true, 32 => true, nil => true}

    # Maps character codes to inline element types for the simple inline elements.
    SIMPLE_INLINE_NAME_MAP = {
      42  => :strong,
      95  => :emphasis,
      126 => :subscript,
      94  => :superscript,
    }

    # Maps character codes of the simple inline element types to the corresponding character.
    SIMPLE_INLINE_CHAR_MAP = {
      42  => '*',
      95  => '_',
      126 => '~',
      94  => '^',
    }

    # Parses a continuation line containing inline elements.
    #
    # The name "continuation line" might be a bit misleading as the first line of a series of such
    # lines is also parsed with this method. However, since parsing is done line by line it is not
    # known whether the line is the first or one of the other lines.
    def parse_continuation_line
      if (@stack.block_boundary? || @stack[-1].type == :extension_block) &&
         @stack.container.content_model == :block
        @stack.append_child(block_node(:paragraph))
      end

      @stack.reset_level(-1)
      start_of_line = @scanner.pos

      if @stack.last_child&.category == :inline && @stack.last_child.type != :hard_break
        @stack.append_child(Node.new(:soft_break), container: false)
      end
      while !@scanner.eos? && (text = @scanner.scan_until(INLINE_RE))
        add_text(text) unless text.empty?
        case (byte = @scanner.scan_byte)
        when 42, 95, 126, 94 # * _ ~ ^
          last_byte = @scanner.string.getbyte(@scanner.pos - 2) if @scanner.pos > 1
          parse_inline_simple(SIMPLE_INLINE_NAME_MAP[byte], SIMPLE_INLINE_CHAR_MAP[byte],
                              !WHITESPACE_LUT[@scanner.peek_byte], !WHITESPACE_LUT[last_byte])
        when 92 # \
          parse_backslash_escape
        when 96 # `
          parse_verbatim(start_of_line)
        when 91 # [
          parse_bracketed_content_opened
        when 93 # ]
          case (byte = @scanner.scan_byte)
          when 40 # (
            parse_bracketed_data_opened(:destination, '](')
          when 91 # [
            parse_bracketed_data_opened(:reference, '][')
          when 123 # {
            parse_simple_span
          else
            @scanner.unscan
            parse_bracketed_data_closed(:reference, start_of_line)
          end
        when 41 # )
          parse_bracketed_data_closed(:destination, start_of_line)
        when 123 # {
          parse_inline_attribute_list_opened('{')
        when 125 # }
          parse_inline_attribute_list_closed(start_of_line)
        when 58 # :
          parse_inline_extension
        when 10, 13 # \n \r
          @scanner.scan_byte if byte == 13 && @scanner.peek_byte == 10
          break
        end
      end

      @stack.each_inline_verbatim do |node|
        start_pos = node[:pos] || start_of_line
        node.content << @scanner.string.byteslice(start_pos, @scanner.pos - start_pos)
        node.properties.delete(:pos)
      end

      @line_no += 1
    end

    # Parses a simple inline element that uses the same marker for opening and closing.
    def parse_inline_simple(type, marker, is_opening, is_closing)
      if (level = @stack.node_level(type)) && is_closing
        @stack.close_node(level)
      elsif is_opening
        @stack.append_child(Node.new(type, properties: {marker: marker}))
      else
        add_text(marker)
      end
    end

    BACKSLASH_ESCAPE_MAP = Hash.new {|h, k| h[k] = k.chr } # :nodoc:
    BACKSLASH_ESCAPE_MAP[32] = "\u00A0"

    # Parses the backslash escape at the current position.
    def parse_backslash_escape
      case (byte = @scanner.scan_byte)
      when 10, 13 # \n \r
        @scanner.unscan
        @stack.append_child(Node.new(:hard_break), container: false)
      else
        add_text(BACKSLASH_ESCAPE_MAP[byte])
      end
    end

    # Parses the verbatim marker at the current position.
    #
    # The argument +start_of_line+ needs to contain the byte position of the start of the line. It
    # is needed in case the verbatim marker is the closing marker and the opening marker was on a
    # previous line.
    def parse_verbatim(start_of_line)
      if (level = @stack.node_level(:verbatim))
        node = @stack[level]
        node.children.clear
        @stack.close_node(level)
        start_pos = node[:pos] || start_of_line
        node.content << @scanner.string.byteslice(start_pos, @scanner.pos - 1 - start_pos)
      else
        @stack.append_child(Node.new(:verbatim, content: +'',
                                     properties: {marker: '`', pos: @scanner.pos}))
      end
    end

    # Parses the opening bracket marker for inline content.
    def parse_bracketed_content_opened
      @stack.append_child(Node.new(:span, properties: {marker: '['}))
    end

    # Parses the opening bracket marker for verbatim data.
    def parse_bracketed_data_opened(data_type, marker = nil)
      if @stack.node_level(:span)
        @stack.append_child(Node.new(:span_data, content: +'',
                                     properties: {marker: marker, data_type: data_type, pos: @scanner.pos}))
      elsif marker
        add_text(marker)
      end
    end

    # Parsers the closing bracket marker for verbatim data.
    def parse_bracketed_data_closed(data_type, start_of_line)
      if (level = @stack.node_level(:span_data)) && @stack[level][:data_type] == data_type
        data_node = @stack.remove_node(level)
        start_pos = data_node[:pos] || start_of_line
        data_node.content << @scanner.string.byteslice(start_pos, @scanner.pos - 1 - start_pos)
        data_node.content.gsub!(/\s*(?:#{EOL_RE_STR})/o, "")

        level = @stack.node_level(:span)
        node = @stack[level]
        if node[:marker] == '['
          node.type = :link
          node[data_type] = data_node.content
        else
          node.type = :inline_extension
          node[:data] = data_node.content
        end
        @stack.close_node(level)
      elsif (level = @stack.node_level(:span)) && @stack[level][:marker] != '['
        @stack[level].type = :inline_extension
        @stack.close_node(level)
      else
        add_text(data_type == :destination ? ')' : ']')
      end
    end

    # Parses a simple span element, i.e. an inline element associated with an attribute list.
    def parse_simple_span
      if @stack.node_level(:span)
        parse_inline_attribute_list_opened(']{')
      else
        add_text(']{')
      end
    end

    # Parses the opening marker of an inline attribute list.
    def parse_inline_attribute_list_opened(marker)
      if ((child = @stack.last_child) && child.type != :text) || marker != '{'
        @stack.append_child(Node.new(:attribute_list, content: +'',
                                     properties: {marker: marker, pos: @scanner.pos}))
      else
        add_text(marker)
      end
    end

    # Parses the closing marker of an inline attribute list.
    def parse_inline_attribute_list_closed(start_of_line)
      if (level = @stack.node_level(:attribute_list))
        al_node = @stack.remove_node(level)
        start_pos = al_node[:pos] || start_of_line
        al_node.content << @scanner.string.byteslice(start_pos, @scanner.pos - 1 - start_pos)

        node = if al_node[:marker] != '{'
                 level = @stack.node_level(:span)
                 node = @stack[level]
                 node.type = :inline_extension unless node[:marker] == '['
                 @stack.close_node(level)
                 node
               else
                 @stack.last_child
               end
        parse_attribute_list_content(al_node.content, node.attributes ||= {})
        node[:refs] = node.attributes.delete(:refs) if node.attributes.key?(:refs)
      else
        add_text('}')
      end
    end

    # Parses the inline extension at the current position.
    def parse_inline_extension
      if @scanner.match?(/(\w+):/o)
        @scanner.pos += @scanner.matched_size
        name = @scanner[1]
        properties = {name: name}
        case (byte = @scanner.scan_byte)
        when 91 # [
          properties[:marker] = ":#{name}:["
          @stack.append_child(Node.new(:span, properties: properties))
        when 40 # (
          properties[:marker] = ":#{name}:("
          @stack.append_child(Node.new(:span, properties: properties))
          parse_bracketed_data_opened(:destination)
        when 123 # {
          @stack.append_child(Node.new(:span, properties: properties))
          parse_inline_attribute_list_opened(":#{name}:{")
        else
          @scanner.unscan
          @stack.append_child(Node.new(:inline_extension, properties: properties), container: false)
        end
      else
        add_text(':')
      end
    end

    # Returns a new block node of the given +type+, +attributes+ and +properties+.
    #
    # This method is designed for block nodes and should not be used for inline nodes.
    def block_node(type, attributes: @attribute_list, properties: nil)
      if attributes && (refs = attributes.delete(:refs))
        properties ||= {}
        (properties[:refs] ||= []).concat(refs)
      end
      @attribute_list = nil
      Node.new(type, attributes: attributes, properties: properties)
    end

    # Adds the given text to the current container element.
    def add_text(text)
      if @stack.last_child&.type == :text
        @stack.last_child.content << text
      else
        @stack.append_child(Node.new(:text, content: +text), container: false)
      end
    end

    AL_ANY_CHARS = /\\\}|[^}]/
    AL_NAME = /[^[:space:].#}]+/
    AL_TYPE_KEY_VALUE_PAIR = /(#{AL_NAME})=(?:("|')((?:\\\}|\\\2|[^}\2])*?)\2|((?:\\\}|[^[:space:]}])+))/
    AL_TYPE_REF = /([^[:space:]]+)/
    AL_TYPE_CLASS = /\.(#{AL_NAME})/
    AL_TYPE_ID = /#(#{AL_NAME})/
    AL_TYPE_ANY = /(?:\A|\s)(?:#{AL_TYPE_KEY_VALUE_PAIR}|#{AL_TYPE_ID}|#{AL_TYPE_CLASS}|#{AL_TYPE_REF})(?=\s|\Z)/
    VALUE_GSUB_RE_MAP = {
      '"' => /\\(\}|")/,
      "'" => /\\(\}|')/,
      nil => /\\(\})/,
    }

    # Parses the content of an attribute list and returns the hash with the attributes.
    def parse_attribute_list_content(str, attrs = {})
      str.strip!
      return attrs if str.empty?

      str.scan(AL_TYPE_ANY).each do |key, quote, val, val1, id_name, class_name, ref|
        if ref
          ref.gsub!(/\\(\})/, "\\1")
          (attrs[:refs] ||= []) << ref
        elsif class_name
          attrs['class'] = "#{attrs['class']} #{class_name}".lstrip
        elsif id_name
          attrs['id'] = id_name
        else
          val ||= val1
          val.gsub!(VALUE_GSUB_RE_MAP[quote], "\\1")
          attrs[key] = val
        end
      end
      attrs
    end

  end

end
