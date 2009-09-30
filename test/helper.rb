require 'rubygems'
require 'test/unit'
require 'mocha'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'autowatchr'

class Test::Unit::TestCase
  def fake_result(name)
    StringIO.new(open(File.dirname(__FILE__) + "/fixtures/results/#{name}.txt").read)
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
end