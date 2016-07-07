require 'dk/has_set_param'
require 'dk/has_ssh_opts'
require 'dk/task'

module Dk

  class Config
    include Dk::HasSetParam
    include Dk::HasSSHOpts

    DEFAULT_INIT_PROCS    = [].freeze
    DEFAULT_PARAMS        = {}.freeze
    DEFAULT_SSH_HOSTS     = {}.freeze
    DEFAULT_SSH_ARGS      = ''.freeze
    DEFAULT_HOST_SSH_ARGS = Hash.new{ |h, k| h[k] = DEFAULT_SSH_ARGS }
    DEFAULT_TASKS         = {}.freeze

    attr_reader :init_procs, :params, :tasks

    def initialize
      @init_procs    = DEFAULT_INIT_PROCS.dup
      @params        = DEFAULT_PARAMS.dup
      @ssh_hosts     = DEFAULT_SSH_HOSTS.dup
      @ssh_args      = DEFAULT_SSH_ARGS.dup
      @host_ssh_args = DEFAULT_HOST_SSH_ARGS.dup
      @tasks         = DEFAULT_TASKS.dup
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

  end

end
