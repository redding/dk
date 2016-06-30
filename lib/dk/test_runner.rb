require 'dk/has_the_runs'
require 'dk/local'
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

    # track that a local cmd was run
    def cmd(cmd_str, opts)
      super(cmd_str, opts).tap{ |c| self.runs << c }
    end

    # track that a local cmd was run
    def cmd!(cmd_str, opts)
      super(cmd_str, opts).tap{ |c| self.runs << c }
    end

    # test task API

    def task(params = nil)
      @task ||= build_task(self.task_class, params)
    end

    # local cmd stub API

    def stub_cmd(cmd_str, opts = nil, &block)
      build_local_cmd(cmd_str, opts).tap{ |spy| block.call(spy) }
    end

    def unstub_cmd(cmd_str, opts = nil)
      local_cmd_spies.delete(local_cmds_key(cmd_str, opts))
    end

    def unstub_all_cmds
      local_cmd_spies.clear
    end

    private

    # don't run any local cmds, always return spies that act like local cmds
    def build_local_cmd(cmd_str, opts)
      local_cmd_spies[local_cmds_key(cmd_str, opts)]
    end

    def local_cmd_spies
      @local_cmd_spies ||= Hash.new{ |h, k| h[k] = Local::CmdSpy.new(*k) }
    end

    def local_cmds_key(cmd_str, opts = nil)
      [cmd_str, opts]
    end

  end

end
