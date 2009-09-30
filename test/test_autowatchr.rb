require 'helper'

class TestAutowatchr < Test::Unit::TestCase
  def new_autowatchr(options = {})
    Autowatchr.new(@script, {
      :ruby => "/usr/local/bin/ruby",
      :lib_dir => @lib_dir,
      :test_dir => @test_dir
    }.merge(options))
  end

  def setup
    @script = stub("fake watchr script", :watch => nil)
    @lib_dir = File.dirname(__FILE__) + "/fixtures/lib"
    @test_dir = File.dirname(__FILE__) + "/fixtures/test"
    Autowatchr.any_instance.stubs(:open)
  end

  def test_new_with_hash
    aw = Autowatchr.new(@script, {
      :ruby => "/usr/local/bin/ruby",
      :include => ".:lib:test"
    })
    assert_equal "/usr/local/bin/ruby", aw.ruby
    assert_equal ".:lib:test", aw.include
  end

  def test_new_with_block
    aw = Autowatchr.new(@script) do |config|
      config.ruby = "/usr/local/bin/ruby"
      config.include = ".:lib:test"
      config.lib_dir = @lib_dir
      config.test_dir = @test_dir
    end
    assert_equal "/usr/local/bin/ruby", aw.ruby
    assert_equal ".:lib:test", aw.include
    assert_equal @lib_dir, aw.lib_dir
    assert_equal @test_dir, aw.test_dir
  end

  def test_auto_includes
    aw = Autowatchr.new(@script) do |config|
      config.ruby = "/usr/local/bin/ruby"
      config.lib_dir = @lib_dir
      config.test_dir = @test_dir
    end
    assert_equal ".:#{@lib_dir}:#{@test_dir}", aw.include
  end

  def test_defaults
    aw = Autowatchr.new(@script)
    assert_equal "ruby", aw.ruby
    assert_equal ".:lib:test", aw.include
    assert_equal "lib", aw.lib_dir
    assert_equal "test", aw.test_dir
  end

  def test_watches_test_files
    md = ["#{@test_dir}/test_foo.rb"]
    Autowatchr.any_instance.expects(:run_test_file).with("#{@test_dir}/test_foo.rb")
    @script.expects(:watch).with("^#{@test_dir}.*/test_.*\.rb").yields(md)
    new_autowatchr
  end

  def test_watches_lib_files
    md = ["#{@lib_dir}/foo.rb"]
    Autowatchr.any_instance.expects(:run_lib_file).with("#{@lib_dir}/foo.rb")
    @script.expects(:watch).with("^#{@lib_dir}.*/.*\.rb").yields(md)
    new_autowatchr
  end

  def test_run_lib_file
    aw = new_autowatchr
    result = fake_result("foo")
    aw.expects(:open).with(
      "| /usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_foo.rb", "r"
    ).yields(result)

    silence_stream(STDOUT) do
      aw.run_lib_file("#{@lib_dir}/foo.rb")
    end
  end
end
