require 'logsly'
require 'dk/has_set_param'
require 'dk/has_ssh_opts'
require 'dk/task'

module Dk

  class Config
    include Dk::HasSetParam
    include Dk::HasSSHOpts

    DEFAULT_INIT_PROCS       = [].freeze
    DEFAULT_PARAMS           = {}.freeze
    DEFAULT_SSH_HOSTS        = {}.freeze
    DEFAULT_SSH_ARGS         = ''.freeze
    DEFAULT_HOST_SSH_ARGS    = Hash.new{ |h, k| h[k] = DEFAULT_SSH_ARGS }
    DEFAULT_TASKS            = {}.freeze
    DEFAULT_LOG_PATTERN      = "%m\n".freeze
    DEFAULT_LOG_FILE_PATTERN = '[%d %-5l] : %m\n'.freeze

    STDOUT_LOG_LEVEL = 'info'.freeze
    FILE_LOG_LEVEL   = 'debug'.freeze

    attr_reader :init_procs, :params, :tasks

    def initialize
      @init_procs       = DEFAULT_INIT_PROCS.dup
      @params           = DEFAULT_PARAMS.dup
      @ssh_hosts        = DEFAULT_SSH_HOSTS.dup
      @ssh_args         = DEFAULT_SSH_ARGS.dup
      @host_ssh_args    = DEFAULT_HOST_SSH_ARGS.dup
      @tasks            = DEFAULT_TASKS.dup
      @log_pattern      = DEFAULT_LOG_PATTERN
      @log_file         = nil
      @log_file_pattern = DEFAULT_LOG_FILE_PATTERN
    end

    def init
      self.init_procs.each{ |block| self.instance_eval(&block) }
    end

    def set_param(key, value)
      self.params.merge!(dk_normalize_params(key => value))
    end

    def before(subject_task_class, callback_task_class, params = nil)
      subject_task_class.before(callback_task_class, params)
    end

    def after(subject_task_class, callback_task_class, params = nil)
      subject_task_class.after(callback_task_class, params)
    end

    def prepend_before(subject_task_class, callback_task_class, params = nil)
      subject_task_class.prepend_before(callback_task_class, params)
    end

    def prepend_after(subject_task_class, callback_task_class, params = nil)
      subject_task_class.prepend_after(callback_task_class, params)
    end

    def task(name, task_class)
      if !task_class.kind_of?(Class) || !task_class.include?(Dk::Task)
        raise ArgumentError, "#{task_class.inspect} is not a Dk::Task"
      end
      @tasks[name.to_s] = task_class
    end

    def log_pattern(value = nil)
      @log_pattern = value if !value.nil?
      @log_pattern
    end

    def log_file(value = nil)
      @log_file = value if !value.nil?
      @log_file
    end

    def log_file_pattern(value = nil)
      @log_file_pattern = value if !value.nil?
      @log_file_pattern
    end

    # private - intended for internal use only

    def dk_logger_stdout_output_name
      # include the object id to ensure the output is unique to the instance
      @dk_logger_stdout_output_name ||= "dk-config-#{self.object_id}-stdout"
    end

    def dk_logger_file_output_name
      # include the object id to ensure the output is unique to the instance
      @dk_logger_file_output_name ||= "dk-config-#{self.object_id}-file"
    end

    def dk_logger
      @dk_logger ||= LogslyLogger.new(self)
    end

    class LogslyLogger
      include Logsly

      LOG_TYPE = 'dk'.freeze

      attr_reader :config

      def initialize(config)
        @config = config # set the reader first so it can be used when supering

        Logsly.stdout(@config.dk_logger_stdout_output_name) do |logger|
          level   Dk::Config::STDOUT_LOG_LEVEL
          pattern logger.config.log_pattern
        end
        outputs = [@config.dk_logger_stdout_output_name]

        if @config.log_file
          Logsly.file(@config.dk_logger_file_output_name) do |logger|
            path    File.expand_path(logger.config.log_file, ENV['PWD'])
            level   Dk::Config::FILE_LOG_LEVEL
            pattern logger.config.log_file_pattern
          end
          outputs << @config.dk_logger_file_output_name
        end

        super(LOG_TYPE, :outputs => outputs)
      end

    end

  end

end
