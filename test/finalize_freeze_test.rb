require 'test_helper'
require 'timeout'

class FinalizeTest < Minitest::Test
  # Use a long-running Node.js process that doesn't exit when stdin is closed
  # This is critical for testing the finalizer because the issue only manifests
  # when the process keeps running after stdin is closed.
  class LongRunningSchmoozer < Schmooze::Base
    # This method keeps the Node.js process running with a setTimeout
    # Even after stdin is closed, the process will wait for the timeout
    method :echo, 'function(x) { setTimeout(() => {}, 60000); return x; }'
  end

  # Test that the finalizer does not hang when the process is still running.
  #
  # This test reproduces an issue where the old finalizer implementation
  # used `Process.kill(0, pid)` which only checks if the process exists
  # instead of actually terminating it. This caused `process_thread.value`
  # to block indefinitely because the Node.js process was waiting for stdin.
  #
  # The fix uses `Process.kill(:KILL, pid)` to actually terminate the process
  # before waiting for it.
  def test_finalizer_does_not_hang
    finalizer = nil
    pid = nil

    # Capture the finalizer without letting it run automatically
    ObjectSpace.stub :define_finalizer, proc { |_s, p| finalizer = p } do
      schmoozer = LongRunningSchmoozer.new(__dir__)
      schmoozer.echo("test")
      pid = schmoozer.pid

      # Verify the process is running
      assert pid, "Process should be running"
      Process.kill(0, pid)  # Should not raise if process is running
    end

    # Run the finalizer with a timeout to detect hanging
    assert_raises_nothing_within(5) do
      finalizer.call
    end

    # Verify the process was killed
    assert_raises Errno::ESRCH do
      Process.kill(0, pid)
    end
  end

  # Test that finalizer properly cleans up multiple instances
  # This tests the scenario where GC.stress is enabled and many instances
  # are created and garbage collected.
  def test_finalizer_handles_multiple_instances_under_gc_pressure
    pids = []
    finalizers = []

    ObjectSpace.stub :define_finalizer, proc { |_s, p| finalizers << p } do
      5.times do
        schmoozer = LongRunningSchmoozer.new(__dir__)
        schmoozer.echo("test")
        pids << schmoozer.pid
      end
    end

    assert_equal 5, pids.length
    assert_equal 5, finalizers.length

    # All finalizers should complete without hanging
    assert_raises_nothing_within(15) do
      finalizers.each(&:call)
    end

    # All processes should be terminated
    pids.each do |pid|
      assert_raises Errno::ESRCH do
        Process.kill(0, pid)
      end
    end
  end

  # Test fork safety: finalizer should only kill process in the original parent
  def test_finalizer_is_fork_safe
    skip "Fork not available on this platform" unless Process.respond_to?(:fork)

    finalizer = nil
    pid = nil

    ObjectSpace.stub :define_finalizer, proc { |_s, p| finalizer = p } do
      schmoozer = LongRunningSchmoozer.new(__dir__)
      schmoozer.echo("test")
      pid = schmoozer.pid
    end

    # Fork and try to run finalizer in child
    child_pid = fork do
      # In child process, finalizer should not kill the process
      # because owner_pid != Process.pid
      finalizer.call
      # Process should still be running (not killed by child)
      begin
        Process.kill(0, pid)
        exit 0  # Success - process still running
      rescue Errno::ESRCH
        exit 1  # Failure - process was killed
      end
    end

    _, status = Process.waitpid2(child_pid)
    assert_equal 0, status.exitstatus, "Child should not kill parent's process"

    # Process should still be running
    Process.kill(0, pid)  # Should not raise if process is still running

    # Now run finalizer in parent - it should kill the process
    assert_raises_nothing_within(5) do
      finalizer.call
    end

    assert_raises Errno::ESRCH do
      Process.kill(0, pid)
    end
  end

  # Test that the close method does not hang with long-running processes.
  # This is similar to the finalizer issue - close() needs to kill the
  # process before waiting for it to exit.
  def test_close_does_not_hang
    schmoozer = LongRunningSchmoozer.new(__dir__)
    schmoozer.echo("test")
    pid = schmoozer.pid

    assert pid, "Process should be running"
    Process.kill(0, pid)  # Should not raise

    # close() should not hang
    assert_raises_nothing_within(5) do
      schmoozer.close
    end

    # Verify the process was killed
    assert_raises Errno::ESRCH do
      Process.kill(0, pid)
    end
  end

  private

  def assert_raises_nothing_within(seconds, message = nil)
    Timeout.timeout(seconds) do
      yield
    end
  rescue Timeout::Error
    flunk(message || "Block did not complete within #{seconds} seconds (likely hung)")
  end
end
