require 'dk/config'
require 'dk/has_set_param'
require 'dk/has_ssh_opts'
require 'dk/local'
require 'dk/null_logger'
require 'dk/remote'

module Dk

  class Runner
    include Dk::HasSetParam
    include Dk::HasSSHOpts

    attr_reader :params, :logger

    def initialize(opts = nil)
      opts ||= {}
      @params = Hash.new{ |h, k| raise ArgumentError, "no param named `#{k}`" }
      @params.merge!(dk_normalize_params(opts[:params]))

      @ssh_hosts     = opts[:ssh_hosts]     || Config::DEFAULT_SSH_HOSTS.dup
      @ssh_args      = opts[:ssh_args]      || Config::DEFAULT_SSH_ARGS.dup
      @host_ssh_args = opts[:host_ssh_args] || Config::DEFAULT_HOST_SSH_ARGS.dup

      @logger = opts[:logger] || NullLogger.new
    end

    # called by CLI on top-level tasks
    def run(task_class, params = nil)
      build_and_run_task(task_class, params)
    end

    # called by other tasks on sub-tasks
    def run_task(task_class, params = nil)
      build_and_run_task(task_class, params)
    end

    def log_info(msg);  self.logger.info(msg);  end # TODO: style up
    def log_debug(msg); self.logger.debug(msg); end # TODO: style up
    def log_error(msg); self.logger.error(msg); end # TODO: style up

    def cmd(cmd_str, opts)
      build_and_run_local_cmd(cmd_str, opts)
    end

    def ssh(cmd_str, opts)
      build_and_run_remote_cmd(cmd_str, opts)
    end

    private

    def build_and_run_task(task_class, params = nil)
      build_task(task_class, params).tap(&:dk_run)
    end

    def build_task(task_class, params = nil)
      task_class.new(self, params)
    end

    def build_and_run_local_cmd(cmd_str, opts, &block)
      log_local_cmd(build_local_cmd(cmd_str, opts)){ |cmd| cmd.run }
    end

    def build_local_cmd(cmd_str, opts)
      Local::Cmd.new(cmd_str, opts)
    end

    def log_local_cmd(cmd, &block)
      self.logger.info(cmd.cmd_str) # TODO: style up
      block.call(cmd)
      cmd.output_lines.each do |output_line|
        self.logger.debug(output_line.line) # TODO: style up, include name
      end
      cmd
    end

    def build_and_run_remote_cmd(cmd_str, opts, &block)
      log_remote_cmd(build_remote_cmd(cmd_str, opts)){ |cmd| cmd.run }
    end

    def build_remote_cmd(cmd_str, opts)
      Remote::Cmd.new(cmd_str, opts)
    end

    def log_remote_cmd(cmd, &block)
      self.logger.info(cmd.cmd_str) # TODO: style up
      block.call(cmd)
      cmd.output_lines.each do |output_line|
        self.logger.debug(output_line.line) # TODO: style up, include name, host
      end
      cmd
    end

  end

end
