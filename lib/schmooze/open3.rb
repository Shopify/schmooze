# frozen_string_literal: true

module Schmooze
  module Open3
    def popen3(*cmd, **opts, &block)
      in_r, in_w = IO.pipe
      opts[:in] = in_r
      in_w.sync = true

      out_r, out_w = IO.pipe
      opts[:out] = out_w

      err_r, err_w = IO.pipe
      opts[:err] = err_w

      popen_run(cmd, opts, [in_r, out_w, err_w], [in_w, out_r, err_r], &block)
    end
    module_function :popen3

    def popen_run(cmd, opts, child_io, parent_io) # :nodoc:
      if last = Hash.try_convert(cmd.last)
        opts = opts.merge(last)
        cmd.pop
      end
      pid = spawn(*cmd, opts)
      wait_thr = Process.detach(pid)

      wait_thr.define_singleton_method(:pid) { pid }

      child_io.each {|io| io.close }
      result = [*parent_io, wait_thr]
      if defined? yield
        begin
          return yield(*result)
        ensure
          parent_io.each{|io| io.close unless io.closed?}
          wait_thr.join
        end
      end
      result
    end
    module_function :popen_run
    class << self
      private :popen_run
    end
  end
end
