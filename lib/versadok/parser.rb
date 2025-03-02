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

module VersaDok

  class Parser

    class Stack

      def initialize(node)
        @stack = [node]
        @level = 0
      end

      def container
        @stack[@level]
      end

      def block_boundary?
        @level + 1 == @stack.size || @stack[-1].children.last&.type == :blank
      end

      def last_child
        @stack[@level].children.last
      end

      def [](level)
        @stack[level]
      end

      def reset_level(level = 0)
        @level = (@stack.size + level) % @stack.size
      end

      def enter
        @level += 1
      end

      def enter_indented(indent)
        @temp = @level + 1
        while @temp < @stack.size && (el_indent = @stack[@temp][:indent]) && el_indent <= indent
          @level = @temp if el_indent > 0
          @temp += 1
        end
      end

      def append_child(node, container: true)
        @stack.slice!((@level + 1)..-1) unless @level + 1 == @stack.size
        @stack.last << node
        if container
          @stack << node
          @level += 1
        end
      end

      def to_s
        @stack.map.with_index {|n, i| @level == i ? "[#{n.type}]" : n.type }.join(' -> ')
      end

    end

    def initialize
      @scanner = StringScanner.new(''.b)
      @stack = Stack.new(Node.new(:root))
      @line_no = 1
    end

    def parse(str)
      @scanner.string = str
      until @scanner.eos?
        @stack.reset_level
        parse_line
      end
      @stack[0]
    end

    def parse_line
      @scanner.scan(/[ \t\v]*/)
      @current_indent = @scanner.matched_size

      @stack.enter_indented(@current_indent) if @current_indent > 0

      case (byte = @scanner.peek_byte)
      when 35 # #
        parse_header
      when 62 # >
        parse_blockquote
      when 42, 43, 45, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57 # * + - 0-9
        parse_list_item(byte)
      when 13, 10, nil # \r \n EOS
        byte = @scanner.scan_byte
        @scanner.scan_byte if byte == 13 && @scanner.peek_byte == 10
        @stack.enter_indented(1000)
        unless @stack.last_child&.type == :blank
          @stack.append_child(Node.new(:blank), container: false)
        end
        @line_no += 1
      else
        parse_continuation_line
      end
    end

    def parse_header
      if @scanner.scan(/\#{1,6} /)
        level = @scanner.matched_size - 1
        if @stack.block_boundary?
          @stack.append_child(Node.new(:header, properties: {level: level}))
        elsif @stack.last_child.type != :header || @stack.last_child[:level] != level
          @scanner.unscan
        end
      end
      parse_continuation_line
    end

    def parse_blockquote
      if @scanner.match?("> ")
        if @stack.last_child&.type == :blockquote
          @scanner.pos += 2
          @stack.enter
          parse_line
        elsif @stack.block_boundary?
          @scanner.pos += 2
          @stack.append_child(Node.new(:blockquote))
          parse_line
        else
          parse_continuation_line
        end
      elsif @scanner.match?(/>(?:\n|\r\n?)/)
        if @stack.last_child&.type == :blockquote
          @scanner.pos += @scanner.matched_size
          @stack.enter
          @stack.enter_indented(1000)
          unless @stack.last_child.type == :blank
            @stack.append_child(Node.new(:blank), container: false)
          end
        else
          parse_continuation_line
        end
        @line_no += 1
      else
        parse_continuation_line
      end
    end

    MARKER_MAP = {
      42 => :asterisk,
      43 => :plus,
      45 => :minus,
    }
    (48..57).each {|byte| MARKER_MAP[byte] = :decimal }

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
          @stack.append_child(Node.new(:list, properties: properties))
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

    def parse_continuation_line
      if @stack.block_boundary? && @stack.container.content_model == :block
        @stack.append_child(Node.new(:paragraph))
      end

      @stack.reset_level(-1)
      add_text(' ') if @stack.last_child&.type == :text
      while !@scanner.eos? && (text = @scanner.scan_until(/(?=\r|\r?\n|\z)/))
        add_text(text)
        case @scanner.peek_byte
        when 10, 13 # \n \r
          @scanner.scan_byte if @scanner.scan_byte == 13 && @scanner.peek_byte == 10
          break
        end
      end
      @line_no += 1
    end

    def add_text(text)
      if @stack.last_child&.type == :text
        @stack.last_child[:content] << text
      else
        @stack.append_child(Node.new(:text, properties: {content: text}), container: false)
      end
    end

  end

end
