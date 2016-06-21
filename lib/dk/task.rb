require 'much-plugin'

module Dk

  module Task
    include MuchPlugin

    plugin_included do
      include InstanceMethods
      extend ClassMethods

    end

    module InstanceMethods

      def dk_run
        # self.dk_run_callbacks 'before_run'
        self.run!
        # self.dk_run_callbacks 'after_run'
      end

      def run!
        raise NotImplementedError
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
