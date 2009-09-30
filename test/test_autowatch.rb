require 'helper'

class TestAutowatch < Test::Unit::TestCase
  def new_autowatch(options = {})
    Autowatch.new({
      :ruby => "/usr/local/bin/ruby",
      :include => ".:lib:test",
      :lib_dir => @lib_dir,
      :test_dir => @test_dir
    }.merge(options))
  end

  def setup
    @lib_dir = File.dirname(__FILE__) + "/fixtures/lib"
    @test_dir = File.dirname(__FILE__) + "/fixtures/test"
  end

  def test_new_with_hash
    aw = Autowatch.new({
      :ruby => "/usr/local/bin/ruby",
      :include => ".:lib:test"
    })
    assert_equal "/usr/local/bin/ruby", aw.ruby
    assert_equal ".:lib:test", aw.include
  end

  def test_new_with_block
    aw = Autowatch.new do |config|
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
    aw = Autowatch.new do |config|
      config.ruby = "/usr/local/bin/ruby"
      config.lib_dir = @lib_dir
      config.test_dir = @test_dir
    end
    assert_equal ".:#{@lib_dir}:#{@test_dir}", aw.include
  end

  def test_defaults
    aw = Autowatch.new
    assert_equal "ruby", aw.ruby
    assert_equal ".:lib:test", aw.include
    assert_equal "lib", aw.lib_dir
    assert_equal "test", aw.test_dir
  end

  def test_run_with_lib_file
    aw = new_autowatch
    result = fake_result("foo")
    aw.expects(:open).with(
      "| /usr/local/bin/ruby -I.:lib:test #{@test_dir}/test_foo.rb", "r"
    ).yields(result)

    aw.run("#{@lib_dir}/foo.rb")
  end
end
