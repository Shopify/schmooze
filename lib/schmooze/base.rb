require 'json'
require 'open3'

require 'schmooze/processor_generator'

module Schmooze
  class Base
    class << self
      def dependencies(deps)
        @imports ||= []
        deps.each do |identifier, package|
          @imports << {
            identifier: identifier,
            package: package
          }
        end
      end

      def method(name, code)
        @methods ||= []
        @methods << {
          name: name,
          code: code
        }

        define_method(name) do |*args|
          call_js_method(name, args)
        end
      end
    end

    def initialize(root, env={})
      @env = env
      @root = root
      @code = ProcessorGenerator.generate(self.class.instance_variable_get(:@imports) || [], self.class.instance_variable_get(:@methods) || [])
      spawn_process
    end

    private
      def spawn_process
        @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(
          @env,
          'node',
          '-e',
          @code,
          chdir: @root
        )
      end

      def call_js_method(method, args)
        @stdin.puts JSON.dump([method, args])
        input = @stdout.gets
        raise Errno::EPIPE, "Can't read from stdout" if input.nil?

        status, return_value = JSON.parse(input)

        if status == 'ok'
          return_value
        else
          raise Sprockets::Error, return_value
        end
      rescue Errno::EPIPE
        raise Error, @stderr.read
      end
  end
end
