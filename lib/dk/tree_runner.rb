require 'dk/dry_runner'
require 'dk/has_the_runs'
require 'dk/null_logger'
require 'dk/task_run'

module Dk

  class TreeRunner < DryRunner
    include HasTheRuns

    LEVEL_PREFIX = '    '.freeze
    LEVEL_BULLET = '|-- '.freeze

    def initialize(config, kernel)
      super(config, :logger => NullLogger.new) # disable any logging

      @task_run_stack = [self]
      @run_num        = 0
      @kernel         = kernel
    end

    def run(*args)
      # wipe the task runs before every run; that way `output_task_runs` outputs
      # just this run's task runs
      self.runs.clear

      # increment the run num and run the task
      @run_num += 1
      task = super

      # recursively output the task runs in a tree format
      output_task_runs(self.runs, 0, "#{@run_num}) ".rjust(LEVEL_PREFIX.size, ' '))

      # return the top-level task that was run
      task
    end

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

    def output_task_runs(runs, level, prefix = nil)
      runs.each do |task_run|
        # recursively output the prefix and task class on indented, bulleted lines
        @kernel.puts "#{LEVEL_PREFIX*level}" \
                     "#{LEVEL_BULLET if level > 0}" \
                     "#{prefix}#{task_run.task_class}"
        output_task_runs(task_run.runs, level+1)
      end

    end

  end

end
