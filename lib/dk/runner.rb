module Dk

  class Runner

    attr_reader :task_class, :task, :params

    def initialize(task_class, args = nil)
      args ||= {}
      @params = Hash.new{ |h, k| raise ArgumentError, "no param named `#{k}`" }
      @params.merge!(args[:params] || {})

      @task_class = task_class
      @task = @task_class.new(self)
    end

    def run
      raise NotImplementedError
    end

  end

end
