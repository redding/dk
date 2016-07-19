require 'dk/has_the_runs'
require 'dk/local'
require 'dk/remote'
require 'dk/runner'
require 'dk/task_run'

module Dk

  class TestRunner < Runner
    include HasTheRuns

    SCMD_TEST_MODE_VALUE = 'yes'.freeze

    attr_accessor :task_class

    # test runners are designed to only run their task
    def run(params = nil)
      orig_scmd_test_mode = ENV['SCMD_TEST_MODE']
      ENV['SCMD_TEST_MODE'] = SCMD_TEST_MODE_VALUE
      task = self.task(params).tap(&:dk_run)
      ENV['SCMD_TEST_MODE'] = orig_scmd_test_mode
      task
    end

    # don't run any sub-tasks, just track that a sub-task was run
    def run_task(task_class, params = nil)
      TaskRun.new(task_class, params).tap{ |tr| self.runs << tr }
    end

    # track that a local cmd was run
    def cmd(cmd_str, input, opts)
      super(cmd_str, input, opts).tap{ |c| self.runs << c }
    end

    # track that a remote cmd was run
    def ssh(cmd_str, input, opts)
      super(cmd_str, input, opts).tap{ |c| self.runs << c }
    end

    # test task API

    def task(params = nil)
      @task ||= build_task(self.task_class, params)
    end

    # cmd stub API

    def stub_cmd(cmd_str, opts = nil, &block)
      build_local_cmd(cmd_str, opts).tap{ |spy| block.call(spy) }
    end

    def unstub_cmd(cmd_str, opts = nil)
      local_cmd_spies.delete(cmd_spy_key(cmd_str, opts))
    end

    def unstub_all_cmds
      local_cmd_spies.clear
    end

    # ssh stub API

    def stub_ssh(cmd_str, opts = nil, &block)
      build_remote_cmd(cmd_str, opts).tap{ |spy| block.call(spy) }
    end

    def unstub_ssh(cmd_str, opts = nil)
      remote_cmd_spies.delete(cmd_spy_key(cmd_str, opts))
    end

    def unstub_all_ssh
      remote_cmd_spies.clear
    end

    private

    # don't run any local cmds, always return spies that act like local cmds
    def build_local_cmd(cmd_str, opts)
      local_cmd_spies[cmd_spy_key(cmd_str, opts)]
    end

    def local_cmd_spies
      @local_cmd_spies ||= Hash.new{ |h, k| h[k] = Local::CmdSpy.new(*k) }
    end

    # don't run any remote cmds, always return spies that act like remote cmds
    def build_remote_cmd(cmd_str, opts)
      remote_cmd_spies[cmd_spy_key(cmd_str, opts)]
    end

    def remote_cmd_spies
      @remote_cmd_spies ||= Hash.new{ |h, k| h[k] = Remote::CmdSpy.new(*k) }
    end

    def cmd_spy_key(cmd_str, opts = nil)
      [cmd_str, opts]
    end

  end

end
