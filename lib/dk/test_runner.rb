require 'dk/has_the_runs'
require 'dk/runner'
require 'dk/task_run'

module Dk

  class TestRunner < Runner
    include HasTheRuns

    # don't run any sub-tasks, just track that a sub-task was run
    def run_task(task_class, params = nil)
      self.runs << TaskRun.new(task_class, params)
    end

    # TODO: don't run any cmds, just track that a cmd was run

    # TODO: disable any logging

  end

end
