require 'test_helper'
require 'versadok/data_dir'

describe "VersaDok.data_dir" do
  before do
    @local = File.expand_path(File.join(__dir__, '..', '..', 'data', 'versadok'))
    @global = File.expand_path(File.join(RbConfig::CONFIG["datadir"], "versadok"))
    VersaDok.remove_instance_variable(:@data_dir) if VersaDok.instance_variable_defined?(:@data_dir)
  end

  after do
    VersaDok.remove_instance_variable(:@data_dir) if VersaDok.instance_variable_defined?(:@data_dir)
  end

  it "returns the 'local' data directory by default, e.g. in case of gem installations" do
    assert_equal(@local, VersaDok.data_dir)
  end

  it "returns the global data directory if the local one isn't found" do
    File.stub(:directory?, lambda {|path| path != @local }) do
      assert_equal(@global, VersaDok.data_dir)
    end
  end

  it "fails if no data directory is found" do
    File.stub(:directory?, lambda {|_path| false }) do
      assert_raises { VersaDok.data_dir }
    end
  end

  it "returns the same data directory every time" do
    dir = VersaDok.data_dir
    assert_same(dir, VersaDok.data_dir)
  end
end
