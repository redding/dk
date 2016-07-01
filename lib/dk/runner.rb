require 'dk/local'
require 'dk/null_logger'

module Dk

  class Runner

    attr_reader :params, :logger

    def initialize(args = nil)
      args ||= {}
      @params = Hash.new{ |h, k| raise ArgumentError, "no param named `#{k}`" }
      @params.merge!(normalize_params(args[:params]))

      @logger = args[:logger] || NullLogger.new
    end

    # called by CLI on top-level tasks
    def run(task_class, params = nil)
      build_and_run_task(task_class, params)
    end

    # called by other tasks on sub-tasks
    def run_task(task_class, params = nil)
      build_and_run_task(task_class, params)
    end

    def set_param(key, value)
      self.params.merge!(normalize_params({ key => value }))
    end

    def log_info(msg);  self.logger.info(msg);  end # TODO: style up
    def log_debug(msg); self.logger.debug(msg); end # TODO: style up
    def log_error(msg); self.logger.error(msg); end # TODO: style up

    def cmd(cmd_str, opts)
      build_and_run_local_cmd(cmd_str, opts)
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

    def normalize_params(params)
      StringifyParams.new(params || {})
    end

    module StringifyParams
      def self.new(object)
        case(object)
        when ::Hash
          object.inject({}){ |h, (k, v)| h.merge(k.to_s => self.new(v)) }
        when ::Array
          object.map{ |item| self.new(item) }
        else
          object
        end
      end
    end

  end

end
