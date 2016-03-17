require 'json'
require 'open3'

require 'schmooze/processor_generator'

module Schmooze
  class Base
    class << self
      protected
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

        def finalize(stdin, stdout, stderr, process_thread)
          proc do
            stdin.close
            stdout.close
            stderr.close
            Process.kill(0, process_thread.pid)
            process_thread.value
          end
        end
    end

    def initialize(root, env={})
      @env = env
      @root = root
      @code = ProcessorGenerator.generate(self.class.instance_variable_get(:@imports) || [], self.class.instance_variable_get(:@methods) || [])

      spawn_process
    end

    def pid
      @process_thread.pid
    end

    private
      def spawn_process
        @stdin, @stdout, @stderr, @process_thread = Open3.popen3(
          @env,
          'node',
          '-e',
          @code,
          chdir: @root
        )
        ensure_packages_are_initiated
        ObjectSpace.define_finalizer(self, self.class.send(:finalize, @stdin, @stdout, @stderr, @process_thread))
      end

      def ensure_packages_are_initiated
        input = @stdout.gets
        raise Schmooze::Error, "Failed to instantiate Schmooze process:\n#{@stderr.read}" if input.nil?
        result = JSON.parse(input)
        unless result[0] == 'ok'
          @stdin.close
          @stdout.close
          @stderr.close
          @process_thread.join

          error_message = result[1]
          if /\AError: Cannot find module '(.*)'\z/ =~ error_message
            package_name = $1
            package_json_path = File.join(@root, 'package.json')
            begin
              package = JSON.parse(File.read(package_json_path))
              %w(dependencies devDependencies).each do |key|
                if package.has_key?(key) && package[key].has_key?(package_name)
                  raise Schmooze::DependencyError, "Cannot find module '#{package_name}'. The module was found in '#{package_json_path}' however, please run 'npm install' from '#{@root}'"
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
        @stdin.puts JSON.dump([method, args])
        input = @stdout.gets
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
      rescue Errno::EPIPE
        # TODO(bouk): restart or something? If this happens the process is completely broken
        raise ::StandardError, "Schmooze process failed:\n#{@stderr.read}"
      end
  end
end
