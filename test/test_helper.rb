# -*- encoding: utf-8 -*-

gem 'strscan'

begin
  require 'simplecov'
  SimpleCov.start do
    enable_coverage :branch
    minimum_coverage line: 100 unless ENV['NO_SIMPLECOV']
    add_filter '/test/'
  end
rescue LoadError
end

require 'minitest/autorun'

TEST_DATA_DIR = File.join(__dir__, 'data')

Minitest::Test.make_my_diffs_pretty!
