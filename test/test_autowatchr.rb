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
    aw = nil
    silence_stream(STDOUT) do
      aw = Autowatchr.new(@script, {
        :ruby => "/usr/local/bin/ruby",
        :include => ".:lib:test"
      })
    end
    assert_equal "/usr/local/bin/ruby", aw.config.ruby
    assert_equal ".:lib:test", aw.config.include
  end

  def test_new_with_block
    aw = nil
    silence_stream(STDOUT) do
      aw = Autowatchr.new(@script) do |config|
        config.ruby = "/usr/local/bin/ruby"
        config.include = ".:lib:test"
        config.lib_dir = @lib_dir
        config.test_dir = @test_dir
      end
    end
    assert_equal "/usr/local/bin/ruby", aw.config.ruby
    assert_equal ".:lib:test", aw.config.include
    assert_equal @lib_dir, aw.config.lib_dir
    assert_equal @test_dir, aw.config.test_dir
  end

  def test_auto_includes
    aw = nil
    silence_stream(STDOUT) do
      aw = Autowatchr.new(@script) do |config|
        config.ruby = "/usr/local/bin/ruby"
        config.lib_dir = @lib_dir
        config.test_dir = @test_dir
      end
    end
    assert_equal ".:#{@lib_dir}:#{@test_dir}", aw.config.include
  end

  def test_defaults
    aw = nil
    silence_stream(STDOUT) do
      aw = Autowatchr.new(@script)
    end
    assert_equal "ruby", aw.config.ruby
    assert_equal ".:lib:test", aw.config.include
    assert_equal "lib", aw.config.lib_dir
    assert_equal "test", aw.config.test_dir
    assert_equal '^lib.*/.*\.rb$', aw.config.lib_re
    assert_equal '^test.*/test_.*\.rb$', aw.config.test_re
    assert_equal /^\s+\d+\) (?:Failure|Error):\n(.*?)\((.*?)\)/, aw.config.failed_results_re
    assert_equal /\d+ tests, \d+ assertions, \d+ failures, \d+ errors/, aw.config.completed_re
  end

  def test_watches_test_files
    @script.expects(:watch).with('^%s.*/test_.*\.rb$' % @test_dir)
    silence_stream(STDOUT) do
      new_autowatchr
    end
  end

  def test_watches_lib_files
    @script.expects(:watch).with('^%s.*/.*\.rb$' % @lib_dir)
    silence_stream(STDOUT) do
      new_autowatchr
    end
  end

  def test_run_lib_file
    result = fake_result("foo")
    expected_cmd = "| /usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_foo.rb"
    Autowatchr.any_instance.expects(:open).with(expected_cmd, "r").yields(result)

    silence_stream(STDOUT) do
      aw = new_autowatchr
      aw.run_lib_file("#{@lib_dir}/foo.rb")
    end
  end

  def test_running_multiple_test_files
    result = fake_result("all")
    expected_cmd = "| /usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} -e \"%w[#{@test_dir}/test_bar.rb #{@test_dir}/test_foo.rb].each { |f| require f }\""
    Autowatchr.any_instance.expects(:open).with(expected_cmd, "r").yields(result)

    silence_stream(STDOUT) do
      aw = new_autowatchr
      aw.run_test_file(["#{@test_dir}/test_bar.rb", "#{@test_dir}/test_foo.rb"])
    end
  end

  def test_runs_all_test_files_on_start
    result = fake_result("all")
    expected_cmd = %!| /usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} -e "%w[#{@test_dir}/test_foo.rb #{@test_dir}/test_bar.rb].each { |f| require f }"!
    Autowatchr.any_instance.expects(:open).with(expected_cmd, "r").yields(result)

    silence_stream(STDOUT) do
      new_autowatchr
    end
  end

  def test_only_runs_failing_tests
    result = fake_result("all")
    Autowatchr.any_instance.stubs(:open).yields(result)
    aw = nil
    silence_stream(STDOUT) do
      aw = new_autowatchr
    end

    result = fake_result("foo_flunk")
    expected_cmd = %!| /usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_foo.rb -n "/^(test_flunk)$/"!
    aw.expects(:open).with(expected_cmd, "r").yields(result)

    silence_stream(STDOUT) do
      aw.run_test_file("#{@test_dir}/test_foo.rb")
    end
  end
end
