require 'test_helper'
require 'versadok/context'

describe VersaDok::Context do
  class ContextTestExtension
    attr_reader :context
    def self.extension_names = ['test', :default]
    def initialize(context)
      @context = context
    end
  end

  before do
    @context = VersaDok::Context.new
  end

  describe "extension" do
    it "returns the given extension if it exists" do
      @context.add_extension(ContextTestExtension)
      assert_kind_of(ContextTestExtension, @context.extension('test'))
    end

    it "raises an error if the extension name doesn't exist and no default is set" do
      @context.instance_variable_get(:@extensions).delete(:default)
      assert_raises(RuntimeError) { @context.extension(:unknown) }
    end

    it "returns the default extension if it is available and the name doesn't exist" do
      ext = @context.add_extension(ContextTestExtension)
      assert_same(ext, @context.extension(:unknown))
    end
  end

  describe "add_extension" do
    it "returns the created extension instance" do
      ext = @context.add_extension(ContextTestExtension)
      assert_same(ext, @context.extension('test'))
      assert_same(@context, ext.context)
    end
  end
end
