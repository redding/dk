require 'benchmark'
require 'set'
require 'dk'
require 'dk/ansi'
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

    TASK_START_LOG_PREFIX  = ' >>>  '.freeze
    TASK_END_LOG_PREFIX    = ' <<<  '.freeze
    INDENT_LOG_PREFIX      = '      '.freeze
    CMD_LOG_PREFIX         = '[CMD] '.freeze
    SSH_LOG_PREFIX         = '[SSH] '.freeze
    CMD_SSH_OUT_LOG_PREFIX = "> ".freeze

    attr_reader :params, :logger

    def initialize(opts = nil)
      opts ||= {}
      @params = Hash.new{ |h, k| raise Dk::NoParamError, "no param named `#{k}`" }
      @params.merge!(dk_normalize_params(opts[:params]))

      d = Config::DEFAULT_CALLBACKS
      @task_callbacks = {
        'before'         => opts[:before_callbacks]         || d.dup,
        'prepend_before' => opts[:prepend_before_callbacks] || d.dup,
        'after'          => opts[:after_callbacks]          || d.dup,
        'prepend_after'  => opts[:prepend_after_callbacks]  || d.dup
      }

      @ssh_hosts     = opts[:ssh_hosts]     || Config::DEFAULT_SSH_HOSTS.dup
      @ssh_args      = opts[:ssh_args]      || Config::DEFAULT_SSH_ARGS.dup
      @host_ssh_args = opts[:host_ssh_args] || Config::DEFAULT_HOST_SSH_ARGS.dup

      @logger = opts[:logger] || NullLogger.new

      @has_run_task_classes = Set.new
    end

    def task_callbacks(named, task_class)
      @task_callbacks[named][task_class] || []
    end

    def task_callback_task_classes(named, task_class)
      task_callbacks(named, task_class).map(&:task_class)
    end

    def add_task_callback(named, subject_task_class, callback_task_class, params)
      @task_callbacks[named][subject_task_class] << Task::Callback.new(
        callback_task_class,
        params
      )
    end

    # called by CLI on top-level tasks
    def run(task_class, params = nil)
      check_run_once_and_build_and_run_task(task_class, params)
    end

    # called by other tasks on sub-tasks
    def run_task(task_class, params = nil)
      check_run_once_and_build_and_run_task(task_class, params)
    end

    def log_info(msg, *ansi_styles)
      self.logger.info("#{INDENT_LOG_PREFIX}#{Ansi.styled_msg(msg, *ansi_styles)}")
    end

    def log_debug(msg, *ansi_styles)
      self.logger.debug("#{INDENT_LOG_PREFIX}#{Ansi.styled_msg(msg, *ansi_styles)}")
    end

    def log_error(msg, *ansi_styles)
      self.logger.error("#{INDENT_LOG_PREFIX}#{Ansi.styled_msg(msg, *ansi_styles)}")
    end

    def log_task_run(task_class, &run_block)
      self.logger.debug "#{TASK_START_LOG_PREFIX}#{task_class}"
      time = Benchmark.realtime(&run_block)
      self.logger.debug "#{TASK_END_LOG_PREFIX}#{task_class} (#{self.pretty_run_time(time)})"
    end

    def log_cli_task_run(task_name, &run_block)
      self.logger.info "Starting `#{task_name}`."
      time = Benchmark.realtime(&run_block)
      self.logger.info "`#{task_name}` finished in #{self.pretty_run_time(time)}."
      self.logger.info ""
      self.logger.info ""
    end

    def log_cli_run(cli_argv, &run_block)
      15.times{ self.logger.debug "" }
      self.logger.debug "===================================="
      self.logger.debug ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> `#{cli_argv}`"
      self.logger.debug "===================================="
      time = Benchmark.realtime(&run_block)
      self.logger.info "(#{self.pretty_run_time(time)})"
      self.logger.debug "===================================="
      self.logger.debug "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< `#{cli_argv}`"
      self.logger.debug "===================================="
    end

    def start(*args)
      build_and_start_local_cmd(*args)
    end

    def cmd(*args)
      build_and_run_local_cmd(*args)
    end

    def ssh(*args)
      build_and_run_remote_cmd(*args)
    end

    def has_run_task?(task_class)
      @has_run_task_classes.include?(task_class)
    end

    def pretty_run_time(raw_run_time)
      if raw_run_time > 1.5 # seconds
        "#{raw_run_time.to_i / 60}:#{(raw_run_time.round % 60).to_i.to_s.rjust(2, '0')}s"
      else
        "#{(raw_run_time * 1000 * 10.0).round / 10.0}ms"
      end
    end

    private

    def check_run_once_and_build_and_run_task(task_class, params = nil)
      if task_class.run_only_once && self.has_run_task?(task_class)
        build_task(task_class, params)
      else
        build_and_run_task(task_class, params)
      end
    end

    def build_and_run_task(task_class, params = nil)
      build_task(task_class, params).tap do |task|
        task.dk_run
        @has_run_task_classes << task_class
      end
    end

    def build_task(task_class, params = nil)
      task_class.new(self, params)
    end

    def build_and_start_local_cmd(*args)
      build_and_log_local_cmd(*args){ |cmd, input| cmd.start(input) }
    end

    def build_and_run_local_cmd(*args)
      build_and_log_local_cmd(*args){ |cmd, input| cmd.run(input) }
    end

    def build_and_log_local_cmd(task, cmd_str, input, given_opts, &block)
      local_cmd = build_local_cmd(task, cmd_str, input, given_opts)
      log_local_cmd(local_cmd){ |cmd| block.call(cmd, input) }
    end

    # input is needed for the `TestRunner` so it can use it with stubbing
    # otherwise it is ignored when building a local cmd
    def build_local_cmd(task, cmd_str, input, given_opts)
      Local::Cmd.new(cmd_str, given_opts)
    end

    def log_local_cmd(cmd, &block)
      self.logger.info("#{CMD_LOG_PREFIX}#{cmd.cmd_str}")
      time = Benchmark.realtime{ block.call(cmd) }
      self.logger.info("#{INDENT_LOG_PREFIX}(#{self.pretty_run_time(time)})")
      cmd.output_lines.each do |output_line|
        self.logger.debug("#{INDENT_LOG_PREFIX}#{CMD_SSH_OUT_LOG_PREFIX}#{output_line.line}")
      end
      cmd
    end

    def build_and_run_remote_cmd(task, cmd_str, input, given_opts, ssh_opts)
      remote_cmd = build_remote_cmd(task, cmd_str, input, given_opts, ssh_opts)
      log_remote_cmd(remote_cmd){ |cmd| cmd.run(input) }
    end

    # input and given opts are needed for the `TestRunner` so it can use it with
    # stubbing otherwise they are ignored when building a remote cmd
    def build_remote_cmd(task, cmd_str, input, given_opts, ssh_opts)
      Remote::Cmd.new(cmd_str, ssh_opts)
    end

    def log_remote_cmd(cmd, &block)
      self.logger.info("#{SSH_LOG_PREFIX}#{cmd.cmd_str}")
      self.logger.debug("#{INDENT_LOG_PREFIX}#{cmd.ssh_cmd_str('<host>')}")
      cmd.hosts.each do |host|
        self.logger.info("#{INDENT_LOG_PREFIX}[#{host}]")
      end
      time = Benchmark.realtime{ block.call(cmd) }
      self.logger.info("#{INDENT_LOG_PREFIX}(#{self.pretty_run_time(time)})")
      cmd.output_lines.each do |ol|
        self.logger.debug "#{INDENT_LOG_PREFIX}[#{ol.host}] " \
                          "#{CMD_SSH_OUT_LOG_PREFIX}#{ol.line}"
      end
      cmd
    end

  end

end
