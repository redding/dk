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

    def log_info(msg);  self.logger.info(msg);  end
    def log_debug(msg); self.logger.debug(msg); end
    def log_error(msg); self.logger.error(msg); end

    private

    def build_and_run_task(task_class, params = nil)
      build_task(task_class, params).tap(&:dk_run)
    end

    def build_task(task_class, params = nil)
      task_class.new(self, params)
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
