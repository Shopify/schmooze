require 'json'
require 'open3'

require 'schmooze/processor_generator'

module Schmooze
  class Base
    class << self
      protected
        def dependencies(deps)
          deps.each do |identifier, package|
            _schmooze_declarations.imports_list << {
              identifier: identifier,
              package: package
            }
          end
        end

        def method(name, code)
          _schmooze_declarations.methods_list << {
            name: name,
            code: code
          }

          define_method(name) do |*args|
            call_js_method(name, args)
          end
        end

        def _schmooze_declarations
          @_schmooze_declarations ||= Declarations.new
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
      @_schmooze_bridge = Bridge.new(
        env: env,
        root: root,
        code: ProcessorGenerator.generate(
          self.class.send(:_schmooze_declarations).imports_list,
          self.class.send(:_schmooze_declarations).methods_list
        )
      )
    end

    def pid
      @_schmooze_bridge.process_thread_pid
    end

    private
      def ensure_process_is_spawned
        return if @_schmooze_bridge.process_thread
        @_schmooze_bridge.spawn_process(self.class)
      end

      def call_js_method(method, args)
        ensure_process_is_spawned

        @_schmooze_bridge.stdin.puts JSON.dump([method, args])
        input = @_schmooze_bridge.stdout.gets
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
        raise ::StandardError, "Schmooze process failed:\n#{@_schmooze_bridge.stderr.read}"
      end

    class Declarations
      attr_accessor :imports_list, :methods_list

      def initialize(imports_list: [], methods_list: [])
        @imports_list = imports_list
        @methods_list = methods_list
      end
    end

    class Bridge
      attr_accessor :env, :root, :code, :process_thread, :stdin, :stdout, :stderr

      def initialize(env: nil, root: nil, code: nil)
        @env = env
        @root = root
        @code = code
      end

      def process_thread_pid
        process_thread && process_thread.pid
      end

      def spawn_process(klass)
        @stdin, @stdout, @stderr, process_thread = Open3.popen3(
          @env,
          'node',
          '-e',
          @code,
          chdir: @root
        )
        ensure_packages_are_initiated(process_thread)
        ObjectSpace.define_finalizer(self, klass.send(:finalize, @stdin, @stdout, @stderr, process_thread))
        @process_thread = process_thread
      end

      def ensure_packages_are_initiated(process_thread)
        input = @stdout.gets
        raise Schmooze::Error, "Failed to instantiate Schmooze process:\n#{@stderr.read}" if input.nil?
        result = JSON.parse(input)
        unless result[0] == 'ok'
          @stdin.close
          @stdout.close
          @stderr.close
          process_thread.join

          error_message = result[1]
          if /\AError: Cannot find module '(.*)'\z/ =~ error_message
            package_name = $1
            package_json_path = File.join(@root, 'package.json')
            begin
              package = JSON.parse(File.read(package_json_path))
              %w(dependencies devDependencies).each do |key|
                if package.has_key?(key) && package[key].has_key?(package_name)
                  raise Schmooze::DependencyError, "Cannot find module '#{package_name}'. The module was found in "\
                    "'#{package_json_path}' however, please run 'npm install' from '#{@root}'"
                end
              end
            rescue Errno::ENOENT
            end
            raise Schmooze::DependencyError, "Cannot find module '#{package_name}'. You need to add it to "\
              "'#{package_json_path}' and run 'npm install'"
          else
            raise Schmooze::Error, error_message
          end
        end
      end
    end

    private_constant :Declarations, :Bridge
  end
end
