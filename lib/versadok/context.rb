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

require_relative 'extension'

module VersaDok

  # Provides context information to the Parser and Renderer.
  class Context

    # The mapping of references to link destinations (used for reference links).
    attr_reader :link_destinations

    # Creates a new Context instance.
    def initialize
      @extensions = {default: Extension.new(self)}
      @link_destinations = {}
      load_builtin_extensions
    end

    # Returns the extension for the given extension +name+.
    #
    # If no extension with the given name exists, the :default extension is returned. If that is not
    # set, an error is raised.
    def extension(name)
      @extensions.fetch(name) do
        @extensions.fetch(:default) do
          raise "No default extension set"
        end
      end
    end

    # Adds a new extension to the context.
    #
    # The +extension_class+ argument must be a class supporting the Extension interface.
    def add_extension(extension_class)
      ext = extension_class.new(self)
      extension_class.extension_names.each do |name|
        @extensions[name] = ext
      end
      ext
    end

    private

    def load_builtin_extensions
      #['template'].each do |name|
      #  require_relative "extensions/#{name}"
      #  add_extension(VersaDok::Extensions.const_get(name.capitalize))
      #end
    end

  end

end
