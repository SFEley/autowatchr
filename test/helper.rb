require 'rubygems'
require 'test/unit'
require 'mocha'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'autowatch'

class Test::Unit::TestCase
  def fake_result(name)
    StringIO.new(open(File.dirname(__FILE__) + "/fixtures/results/#{name}.txt").read)
  end
end
