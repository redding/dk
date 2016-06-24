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
        # self.dk_run_callbacks 'before_run'
        self.run!
        # self.dk_run_callbacks 'after_run'
      end

      def run!
        raise NotImplementedError
      end

      private

      # Helpers

      def params
        @dk_params
      end

      def set_param(key, value)
        @dk_runner.set_param(key, value)
      end

      def run_task(task_class, params = nil)
        @dk_runner.run_task(task_class, params)
      end

    end

    module ClassMethods

      def description(value = nil)
        @description = value.to_s if !value.nil?
        @description
      end
      alias_method :desc, :description

    end

  end

end
