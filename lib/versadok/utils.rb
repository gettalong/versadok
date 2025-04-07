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
  module Utils

    # This module refines the core Hash class to provide the #deep_merge and #deep_merge! methods
    # that allow deep-merging of nested Hash structures.
    module HashDeepMerge
      refine Hash do

        # Merges the +other+ Hash with a copy of +self+ and returns the result.
        def deep_merge(other)
          dup.deep_merge!(other)
        end

        # Merges the +other+ Hash with +self+ and returns +self+.
        def deep_merge!(other)
          merge!(other) do |key, old_value, new_value|
            if old_value.kind_of?(Hash) && new_value.kind_of?(Hash)
              old_value.deep_merge(new_value)
            else
              new_value
            end
          end
        end
      end
    end

  end
end
