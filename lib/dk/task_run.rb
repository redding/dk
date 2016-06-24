require 'dk/has_the_runs'

module Dk

  class TaskRun
    include HasTheRuns

    attr_reader :task_class, :params

    def initialize(task_class, params)
      @task_class = task_class
      @params     = params
    end

  end

end
