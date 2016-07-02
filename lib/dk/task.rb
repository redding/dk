require 'much-plugin'

module Dk

  module Task
    include MuchPlugin

    plugin_included do
      include InstanceMethods
      extend ClassMethods

    end

    module InstanceMethods

      def initialize(runner, params = nil)
        params ||= {}
        @dk_runner = runner
        @dk_params = Hash.new{ |h, k| @dk_runner.params[k] }
        @dk_params.merge!(params)
      end

      def dk_run
        self.dk_run_callbacks 'before'
        catch(:halt){ self.run! }
        self.dk_run_callbacks 'after'
      end

      def run!
        raise NotImplementedError
      end

      def dk_run_callbacks(named)
        (self.class.send("#{named}_callbacks") || []).each do |callback|
          run_task(callback.task_class, callback.params)
        end
      end

      def ==(other_task)
        self.class == other_task.class
      end

      private

      # Helpers

      def run_task(task_class, params = nil)
        @dk_runner.run_task(task_class, params)
      end

      def cmd(cmd_str, opts = nil)
        @dk_runner.cmd(cmd_str, opts)
      end

      def cmd!(cmd_str, opts = nil)
        cmd = @dk_runner.cmd(cmd_str, opts)
        if !cmd.success?
          raise CmdRunError, "error running `#{cmd.cmd_str}`", caller
        end
        cmd
      end

      def ssh(cmd_str, opts = nil)
        @dk_runner.ssh(cmd_str, opts)
      end

      def ssh!(cmd_str, opts = nil)
        cmd = @dk_runner.ssh(cmd_str, opts)
        if !cmd.success?
          raise SSHRunError, "error running `#{cmd.cmd_str}` over ssh", caller
        end
        cmd
      end

      def params
        @dk_params
      end

      def set_param(key, value)
        @dk_runner.set_param(key, value)
      end

      def halt
        throw :halt
      end

      def log_info(msg);  @dk_runner.log_info(msg);  end
      def log_debug(msg); @dk_runner.log_debug(msg); end
      def log_error(msg); @dk_runner.log_error(msg); end

    end

    CmdRunError = Class.new(RuntimeError)
    SSHRunError = Class.new(RuntimeError)

    module ClassMethods

      def description(value = nil)
        @description = value.to_s if !value.nil?
        @description
      end
      alias_method :desc, :description

      def before_callbacks; @before_callbacks ||= []; end
      def after_callbacks;  @after_callbacks  ||= []; end

      def before(task_class, params = nil)
        self.before_callbacks << Callback.new(task_class, params)
      end

      def after(task_class, params = nil)
        self.after_callbacks << Callback.new(task_class, params)
      end

      def prepend_before(task_class, params = nil)
        self.before_callbacks.unshift(Callback.new(task_class, params))
      end

      def prepend_after(task_class, params = nil)
        self.after_callbacks.unshift(Callback.new(task_class, params))
      end

    end

    Callback = Struct.new(:task_class, :params)

    module TestHelpers
      include MuchPlugin

      plugin_included do
        require 'dk/test_runner'
        include InstanceMethods
      end

      module InstanceMethods

        def test_runner(task_class, args = nil)
          Dk::TestRunner.new(args).tap do |runner|
            runner.task_class = task_class
          end
        end

        def test_task(task_class, args = nil)
          test_runner(task_class, args).task
        end

      end

    end

  end

end
