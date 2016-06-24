require 'dk/dry_runner'
require 'dk/has_the_runs'
require 'dk/task_run'

module Dk

  class TreeRunner < DryRunner
    include HasTheRuns

    def initialize(*args)
      super
      @task_run_stack = [self]
    end

    def run(*args)
      super
      # TODO: log out view of nested task runs
    end

    # TODO: disable any logging

    private

    # track all task runs
    def build_and_run_task(task_class, params = nil)
      task_run = TaskRun.new(task_class, params)
      @task_run_stack.last.runs << task_run

      @task_run_stack.push(task_run)
      task = super(task_class, params)
      @task_run_stack.pop
      task
    end

  end

end
