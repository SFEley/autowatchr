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
    Autowatchr.any_instance.stubs_system_call
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
    expected_cmd = "/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_foo.rb"
    Autowatchr.any_instance.expects_system_call(expected_cmd, "foo")

    silence_stream(STDOUT) do
      aw = new_autowatchr
      aw.run_lib_file("#{@lib_dir}/foo.rb")
    end
  end

  def test_running_multiple_test_files
    expected_cmd = "/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} -e \"%w[#{@test_dir}/test_bar.rb #{@test_dir}/test_foo.rb].each do |f| require f end\""
    Autowatchr.any_instance.expects_system_call(expected_cmd, "all")

    silence_stream(STDOUT) do
      aw = new_autowatchr
      aw.run_test_file(["#{@test_dir}/test_bar.rb", "#{@test_dir}/test_foo.rb"])
    end
  end

  def test_runs_all_test_files_on_start
    files = Dir.glob("#{@test_dir}/**/test_*.rb").join(" ")
    expected_cmd = %!/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} -e "%w[#{files}].each do |f| require f end"!
    Autowatchr.any_instance.expects_system_call(expected_cmd, "all")

    silence_stream(STDOUT) do
      new_autowatchr
    end
  end

  def test_mapping_test_classes_to_test_files
    aw = nil
    silence_stream(STDOUT) do
      aw = new_autowatchr
    end
    assert_equal "#{@test_dir}/test_foo.rb", aw.classname_to_path("TestFoo")
    assert_equal "#{@test_dir}/test_foo/test_baz.rb", aw.classname_to_path("TestFoo::TestBaz")
  end

  def test_only_runs_failing_tests
    Autowatchr.any_instance.stubs_system_call("all")
    aw = nil
    silence_stream(STDOUT) do
      aw = new_autowatchr
    end

    expected_cmd = %!/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_foo.rb -n "/^(test_flunk)$/"!
    aw.expects_system_call(expected_cmd, "foo_flunk")

    silence_stream(STDOUT) do
      aw.run_test_file("#{@test_dir}/test_foo.rb")
    end
  end

  def test_only_registers_failing_test_once
    Autowatchr.any_instance.stubs_system_call("all")
    aw = nil
    silence_stream(STDOUT) do
      aw = new_autowatchr
    end

    expected_cmd = %!/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_foo.rb -n "/^(test_flunk)$/"!
    aw.expects_system_call(expected_cmd, "foo_flunk")
    silence_stream(STDOUT) do
      aw.run_test_file("#{@test_dir}/test_foo.rb")
    end

    expected_cmd = %!/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_foo.rb -n "/^(test_flunk)$/"!
    aw.expects_system_call(expected_cmd, "foo_flunk")
    silence_stream(STDOUT) do
      aw.run_test_file("#{@test_dir}/test_foo.rb")
    end
  end

  def test_clears_failing_test_when_it_passes
    Autowatchr.any_instance.stubs_system_call("all")
    aw = nil
    silence_stream(STDOUT) do
      aw = new_autowatchr
    end

    aw.stubs_system_call("foo_pass")
    silence_stream(STDOUT) do
      aw.run_test_file("#{@test_dir}/test_foo.rb")
    end

    expected_cmd = %!/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_foo.rb!
    aw.expects_system_call(expected_cmd, "foo")
    silence_stream(STDOUT) do
      aw.run_test_file("#{@test_dir}/test_foo.rb")
    end
  end

  def test_not_only_running_failing_tests
    Autowatchr.any_instance.stubs_system_call("all")
    aw = nil
    silence_stream(STDOUT) do
      aw = new_autowatchr(:failing_only => false)
    end

    expected_cmd = %!/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_foo.rb!
    aw.expects_system_call(expected_cmd, "foo")
    silence_stream(STDOUT) do
      aw.run_test_file("#{@test_dir}/test_foo.rb")
    end
  end

  def test_running_entire_suite_after_green
    Autowatchr.any_instance.stubs_system_call("all")
    aw = nil
    silence_stream(STDOUT) do
      aw = new_autowatchr
    end

    expected_cmd_2 = %!/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_foo.rb -n "/^(test_flunk)$/"!
    aw.expects_system_call(expected_cmd_2, "foo_pass")
    silence_stream(STDOUT) do
      aw.run_test_file("#{@test_dir}/test_foo.rb")
    end

    expected_cmd_3 = %!/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_bar.rb -n "/^(test_flunk)$/"!
    aw.expects_system_call(expected_cmd_3, "bar_pass")

    files = Dir.glob("#{@test_dir}/**/test_*.rb").join(" ")
    expected_cmd_4 = %!/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} -e "%w[#{files}].each do |f| require f end"!
    aw.expects_system_call(expected_cmd_4, "all")

    silence_stream(STDOUT) do
      aw.run_test_file("#{@test_dir}/test_bar.rb")
    end
  end

  def test_not_running_entire_suite_after_green
    Autowatchr.any_instance.stubs_system_call("all")
    aw = nil
    silence_stream(STDOUT) do
      aw = new_autowatchr(:run_suite => false)
    end

    expected_cmd_2 = %!/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_foo.rb -n "/^(test_flunk)$/"!
    aw.expects_system_call(expected_cmd_2, "foo_pass")
    silence_stream(STDOUT) do
      aw.run_test_file("#{@test_dir}/test_foo.rb")
    end

    expected_cmd_3 = %!/usr/local/bin/ruby -I.:#{@lib_dir}:#{@test_dir} #{@test_dir}/test_bar.rb -n "/^(test_flunk)$/"!
    aw.expects_system_call(expected_cmd_3, "bar_pass")

    silence_stream(STDOUT) do
      aw.run_test_file("#{@test_dir}/test_bar.rb")
    end
  end
end
