require File.dirname(__FILE__) + "/helper"

class TestFoo < Test::Unit::TestCase
  def test_pass
    assert true
  end

  def test_flunk
    flunk
  end
end
