module Dk

  class Runner

    attr_reader :params

    def initialize(args = nil)
      args ||= {}
      @params = Hash.new{ |h, k| raise ArgumentError, "no param named `#{k}`" }
      @params.merge!(args[:params] || {})
    end

    def run(task_class, params = nil)
      raise NotImplementedError
    end

  end

end
