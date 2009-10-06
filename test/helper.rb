require 'rubygems'
require 'test/unit'
require 'mocha'
require 'pp'
require 'ruby-debug'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'autowatchr'

class Test::Unit::TestCase
end

module Mocha::ObjectMethods
  def stubs_system_call(result_name = nil)
    self.stubs(:system).with() do |_|
      $stdout.print(result_name ? fake_result(result_name) : "")
      true
    end
  end

  def expects_system_call(expected_command, result_name = nil)
    self.expects(:system).with() do |actual_command|
      if expected_command == actual_command
        $stdout.print(result_name ? fake_result(result_name) : "")
        true
      else
        false
      end
    end
  end
end

def fake_result(name)
  open(File.dirname(__FILE__) + "/fixtures/results/#{name}.txt").read
end

# File vendor/rails/activesupport/lib/active_support/core_ext/kernel/reporting.rb, line 36
def silence_stream(stream)
  old_stream = stream.dup
  stream.reopen(RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
  stream.sync = true
  yield
ensure
  stream.reopen(old_stream)
end

def debug_p(obj, label = nil)
  $stderr.print "#{label}: "  if label
  $stderr.puts obj.inspect
end
