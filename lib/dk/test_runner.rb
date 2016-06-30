require 'dk/has_the_runs'
require 'dk/runner'
require 'dk/task_run'

module Dk

  class TestRunner < Runner
    include HasTheRuns

    attr_accessor :task_class

    # test runners are designed to only run their task
    def run(params = nil)
      self.task(params).tap(&:dk_run)
    end

    # don't run any sub-tasks, just track that a sub-task was run
    def run_task(task_class, params = nil)
      TaskRun.new(task_class, params).tap{ |tr| self.runs << tr }
    end

    # test task API

    def task(params = nil)
      @task ||= build_task(self.task_class, params)
    end

  end

end
