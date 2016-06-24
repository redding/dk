module Dk

  class Runner

    attr_reader :params

    def initialize(args = nil)
      args ||= {}
      @params = Hash.new{ |h, k| raise ArgumentError, "no param named `#{k}`" }
      @params.merge!(normalize_params(args[:params]))
    end

    def run(task_class, params = nil)
      raise NotImplementedError
    end

    def set_param(key, value)
      @params.merge!(normalize_params({ key => value }))
    end

    private

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
