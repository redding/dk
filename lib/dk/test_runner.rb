require 'dk/has_the_runs'
require 'dk/runner'
require 'dk/task_run'

module Dk

  class TestRunner < Runner
    include HasTheRuns

    attr_accessor :task_class

    def task(params = nil)
      build_task(self.task_class, params)
    end

    # test runners are designed to only run their task class's tasks
    def run(params = nil)
      super(self.task_class, params)
    end

    # don't run any sub-tasks, just track that a sub-task was run
    def run_task(task_class, params = nil)
      self.runs << TaskRun.new(task_class, params)
    end

    # TODO: don't run any cmds, just track that a cmd was run

    # TODO: disable any logging

  end

end
