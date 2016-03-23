require 'test_helper'

class GarbageTest < Minitest::Test
  class GarbageSchmoozer < Schmooze::Base
    method :test, 'function(){ return 1; }'
  end

  def test_process_is_not_started_until_used
    garbage = GarbageSchmoozer.new(__dir__)
    assert_nil garbage.pid
    garbage.test
    assert garbage.pid
  end

  def test_process_is_closed
    # Hacky way to test the finalizer. There is no way to guarantee that the
    # finalizer is called so instead we stub define_finalizer to call it immediately
    finalizer = nil
    ObjectSpace.stub :define_finalizer, proc {|s, p| finalizer = p} do
      garbage = GarbageSchmoozer.new(__dir__)
      garbage.test
      pid = garbage.pid
      finalizer.call
      assert_raises Errno::ESRCH do
        Process.kill(0, pid)
      end
    end
  end
end
