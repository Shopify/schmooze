require 'test_helper'

class GarbageTest < Minitest::Test
  def test_process_is_closed
    # Hacky way to test the finalizer. There is no way to guarantee that the
    # finalizer is called so instead we stub define_finalizer to call it immediately
    ObjectSpace.stub :define_finalizer, proc {|s, p| p.call} do
      pid = Schmooze::Base.new(__dir__).pid
      assert_raises Errno::ESRCH do
        Process.kill(0, pid)
      end
    end
  end
end
