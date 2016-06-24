require 'much-plugin'

module Dk

  module HasTheRuns
    include MuchPlugin

    plugin_included do
      include InstanceMethods

    end

    module InstanceMethods

      def runs
        @runs ||= []
      end

    end

  end

end
