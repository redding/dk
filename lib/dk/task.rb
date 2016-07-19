require 'much-plugin'
require 'dk/remote'

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
        catch(:halt) do
          halt if self.class.run_only_once && @dk_runner.has_run_task?(self.class)
          self.run!
        end
        self.dk_run_callbacks 'after'
      end

      def run!
        raise NotImplementedError
      end

      def dk_run_callbacks(named)
        callbacks  = @dk_runner.task_callbacks("prepend_#{named}", self.class)
        callbacks += (self.class.send("#{named}_callbacks") || [])
        callbacks += @dk_runner.task_callbacks(named, self.class)
        callbacks.each{ |c| run_task(c.task_class, c.params) }
      end

      def dk_dsl_ssh_hosts
        @dk_dsl_ssh_hosts ||= self.instance_eval(&self.class.ssh_hosts)
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
        @dk_runner.ssh(cmd_str, dk_build_ssh_opts(opts))
      end

      def ssh!(cmd_str, opts = nil)
        cmd = ssh(cmd_str, opts)
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

      def ssh_hosts(group_name = nil, *values)
        @dk_runner.ssh_hosts(group_name, *values)
      end

      def ssh_cmd_str(cmd_str, opts = nil)
        opts ||= {}
        Remote.ssh_cmd_str(
          cmd_str,
          opts[:host].to_s,
          dk_lookup_ssh_args(opts[:ssh_args]),
          dk_lookup_host_ssh_args(opts[:host_ssh_args])
        )
      end

      def halt
        throw :halt
      end

      def log_info(msg);  @dk_runner.log_info(msg);  end
      def log_debug(msg); @dk_runner.log_debug(msg); end
      def log_error(msg); @dk_runner.log_error(msg); end

      def dk_build_ssh_opts(opts)
        opts ||= {}
        opts.merge({
          :hosts         => dk_lookup_ssh_hosts(opts[:hosts]),
          :ssh_args      => dk_lookup_ssh_args(opts[:ssh_args]),
          :host_ssh_args => dk_lookup_host_ssh_args(opts[:host_ssh_args])
        })
      end

      def dk_lookup_ssh_hosts(opts_hosts)
        [*(
          ssh_hosts[opts_hosts] ||
          opts_hosts ||
          ssh_hosts[self.dk_dsl_ssh_hosts] ||
          self.dk_dsl_ssh_hosts
        )]
      end

      def dk_lookup_ssh_args(opts_args)
        opts_args || @dk_runner.ssh_args
      end

      def dk_lookup_host_ssh_args(opts_args)
        opts_args || @dk_runner.host_ssh_args
      end

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

      def before_callback_task_classes; self.before_callbacks.map(&:task_class); end
      def after_callback_task_classes;  self.after_callbacks.map(&:task_class);  end

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

      def ssh_hosts(value = nil, &block)
        @ssh_hosts = block || proc{ value } if !block.nil? || !value.nil?
        @ssh_hosts || proc{}
      end

      def run_only_once(value = nil)
        @run_only_once = !!value if !value.nil?
        @run_only_once
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

        def ssh_cmd_str(task, *args)
          task.instance_eval{ ssh_cmd_str(*args) }
        end

      end

    end

  end

end
