require 'much-plugin'

module Dk

  module HasSetParam
    include MuchPlugin

    plugin_included do
      include InstanceMethods

    end

    module InstanceMethods

      def set_param(key, value)
        self.params.merge!(dk_normalize_params(key => value))
      end

      private

      def dk_normalize_params(params)
        StringifyParams.new(params || {})
      end

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
