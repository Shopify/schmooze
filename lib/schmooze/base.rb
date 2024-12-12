require 'json'
require 'open3'

require 'schmooze/processor_generator'

module Schmooze
  class Base
    class << self
      protected
        def dependencies(deps)
          @_schmooze_imports ||= []
          deps.each do |identifier, package|
            @_schmooze_imports << {
              identifier: identifier,
              package: package
            }
          end
        end

        def method(name, code)
          @_schmooze_methods ||= []
          @_schmooze_methods << {
            name: name,
            code: code
          }

          define_method(name) do |*args|
            call_js_method(name, args)
          end
        end

        def finalize(owner_pid, stdin, stdout, stderr, process_thread)
          proc do
            # First check if we're still the owner. e.g. if there was a fork
            # this finalizer will be called in both the child and the parent.
            # Only the parent should care about the subprocess.
            if owner_pid == Process.pid
              stdin.close
              stdout.close
              stderr.close
              begin
                Process.kill(:KILL, process_thread.pid)
              rescue Errno::ESRCH
                # Process is already dead, so no worries.
              end
              process_thread.value
            end
          end
        end
    end

    def initialize(root, env={})
      @_schmooze_env = env
      @_schmooze_root = root
      @_schmooze_code = ProcessorGenerator.generate(self.class.instance_variable_get(:@_schmooze_imports) || [], self.class.instance_variable_get(:@_schmooze_methods) || [])
    end

    def pid
      @_schmooze_process_thread && @_schmooze_process_thread.pid
    end

    def close
      @_schmooze_stdin.close
      @_schmooze_stdout.close
      @_schmooze_stderr.close
      @_schmooze_process_thread.value
    end

    private
      def ensure_process_is_spawned
        return if @_schmooze_process_thread
        spawn_process
      end

      def spawn_process
        process_data = Open3.popen3(
          @_schmooze_env,
          ENV.fetch('NODEJS_EXECUTABLE_PATH', 'node'),
          '-e',
          @_schmooze_code,
          chdir: @_schmooze_root
        )
        ensure_packages_are_initiated(*process_data)
        ObjectSpace.define_finalizer(self, self.class.send(:finalize, Process.pid, *process_data))
        @_schmooze_stdin, @_schmooze_stdout, @_schmooze_stderr, @_schmooze_process_thread = process_data
      end

      def ensure_packages_are_initiated(stdin, stdout, stderr, process_thread)
        input = stdout.gets
        raise Schmooze::Error, "Failed to instantiate Schmooze process:\n#{stderr.read}" if input.nil?
        result = JSON.parse(input)
        unless result[0] == 'ok'
          stdin.close
          stdout.close
          stderr.close
          process_thread.join

          error_message = result[1]
          if /\AError: Cannot find module '(.*)'$/ =~ error_message
            package_name = $1
            package_json_path = File.join(@_schmooze_root, 'package.json')
            begin
              package = JSON.parse(File.read(package_json_path))
              %w(dependencies devDependencies).each do |key|
                if package.has_key?(key) && package[key].has_key?(package_name)
                  raise Schmooze::DependencyError, "Cannot find module '#{package_name}'. The module was found in '#{package_json_path}' however, please run 'npm install' from '#{@_schmooze_root}'"
                end
              end
            rescue Errno::ENOENT
            end
            raise Schmooze::DependencyError, "Cannot find module '#{package_name}'. You need to add it to '#{package_json_path}' and run 'npm install'"
          else
            raise Schmooze::Error, error_message
          end
        end
      end

      def call_js_method(method, args)
        ensure_process_is_spawned

        @_schmooze_stdin.puts JSON.dump([method, args])
        input = @_schmooze_stdout.gets
        raise Errno::EPIPE, "Can't read from stdout" if input.nil?

        status, message, error_class = JSON.parse(input)

        if status == 'ok'
          message
        else
          if error_class.nil?
            raise Schmooze::JavaScript::UnknownError, message
          else
            raise Schmooze::JavaScript.const_get(error_class, false), message
          end
        end
      rescue Errno::EPIPE, IOError
        # TODO(bouk): restart or something? If this happens the process is completely broken
        raise ::StandardError, "Schmooze process failed:\n#{@_schmooze_stderr.read}"
      end
  end
end
