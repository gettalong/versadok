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

module VersaDok

  class Node

    CATEGORY_MAP = { #:nodoc:
      root: :block,
      blockquote: :block,
      list_item: :block,
      header: :block,
      paragraph: :block,
      strong: :inline,
      emphasis: :inline,
      subscript: :inline,
      superscript: :inline,
      text: :inline,
      verbatim: :inline,
      link: :inline,
      span: :inline,
      attribute_list: :inline,
      span_data: :inline,
      soft_break: :inline,
      hard_break: :inline,
      inline_extension: :inline,
    }

    CONTENT_MODEL_MAP = { #:nodoc:
      root: :block,
      blockquote: :block,
      list_item: :block,
      header: :inline,
      paragraph: :inline,
      strong: :inline,
      emphasis: :inline,
      subscript: :inline,
      superscript: :inline,
      text: :none,
      verbatim: :verbatim,
      link: :inline,
      span: :inline,
      span_data: :verbatim,
      attribute_list: :verbatim,
      soft_break: :none,
      hard_break: :none,
      inline_extension: :none,
    }

    attr_accessor :type
    attr_accessor :content
    attr_accessor :attributes
    attr_accessor :properties

    def initialize(type, content: nil, attributes: nil, properties: nil)
      @type = type
      @content = content
      @attributes = attributes
      @properties = properties
      @children = nil
    end

    def children
      @children ||= []
    end

    def category
      properties&.[](:category) || CATEGORY_MAP[@type]
    end

    def content_model
      properties&.[](:content_model) || CONTENT_MODEL_MAP[@type]
    end

    def unique_type
      case type
      when :header then :"header#{self[:level]}"
      when :list then :"list_#{self[:marker]}"
      else type
      end
    end

    def [](key)
      properties && properties[key]
    end

    def []=(key, value)
      (@properties ||= {})[key] = value
    end

    def <<(node)
      children << node
      self
    end

    def to_s(indent = 0)
      str = "#{' ' * indent}#{@type} #{content && content.inspect} #{properties&.inspect} " \
            "#{@attributes&.map {|k,v| "#{k}=#{v.inspect}"}&.join(' ')}".rstrip
      str << "\n#{@children.map {|c| c.to_s(indent + 2)}.join("\n")}" unless children.empty?
      str
    end

  end

end
