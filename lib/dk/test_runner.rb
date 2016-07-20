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
    def cmd(cmd_str, input, given_opts)
      super(cmd_str, input, given_opts).tap{ |c| self.runs << c }
    end

    # track that a remote cmd was run
    def ssh(cmd_str, input, given_opts, ssh_opts)
      super(cmd_str, input, given_opts, ssh_opts).tap{ |c| self.runs << c }
    end

    # test task API

    def task(params = nil)
      @task ||= build_task(self.task_class, params)
    end

    # cmd stub API

    def stub_cmd(cmd_str, *args, &block)
      given_opts = args.last.kind_of?(::Hash) ? args.pop : nil
      input      = args.last
      local_cmd_spy_blocks[cmd_spy_key(cmd_str, input, given_opts)] = block
    end

    def unstub_cmd(cmd_str, *args)
      given_opts = args.last.kind_of?(::Hash) ? args.pop : nil
      input      = args.last

      key = cmd_spy_key(cmd_str, input, given_opts)
      local_cmd_spy_blocks.delete(key)
      local_cmd_spies.delete(key)
    end

    def unstub_all_cmds
      local_cmd_spy_blocks.clear
      local_cmd_spies.clear
    end

    # ssh stub API

    def stub_ssh(cmd_str, *args, &block)
      given_opts = args.last.kind_of?(::Hash) ? args.pop : nil
      input      = args.last
      remote_cmd_spy_blocks[cmd_spy_key(cmd_str, input, given_opts)] = block
    end

    def unstub_ssh(cmd_str, *args)
      given_opts = args.last.kind_of?(::Hash) ? args.pop : nil
      input      = args.last

      key = cmd_spy_key(cmd_str, input, given_opts)
      remote_cmd_spy_blocks.delete(key)
      remote_cmd_spies.delete(key)
    end

    def unstub_all_ssh
      remote_cmd_spy_blocks.clear
      remote_cmd_spies.clear
    end

    private

    # don't run any local cmds, always return spies that act like local cmds
    def build_local_cmd(cmd_str, input, given_opts)
      key = cmd_spy_key(cmd_str, input, given_opts)
      local_cmd_spies[key] ||= begin
        block = local_cmd_spy_blocks[key] || Proc.new{ |spy| }
        Local::CmdSpy.new(cmd_str, given_opts).tap(&block)
      end
    end

    def local_cmd_spies
      @local_cmd_spies ||= {}
    end

    def local_cmd_spy_blocks
      @local_cmd_spy_blocks ||= {}
    end

    # don't run any remote cmds, always return spies that act like remote cmds;
    # lookup cmd spies using the given opts but build them using the ssh opts,
    # this allows stubbing and calling ssh cmds with the same opts but also
    # allows building a valid remote cmd that has an ssh host
    def build_remote_cmd(cmd_str, input, given_opts, ssh_opts)
      key = cmd_spy_key(cmd_str, input, given_opts)
      remote_cmd_spies[key] ||= begin
        block = remote_cmd_spy_blocks[key] || Proc.new{ |spy| }
        Remote::CmdSpy.new(cmd_str, ssh_opts).tap(&block)
      end
    end

    def remote_cmd_spies
      @remote_cmd_spies ||= {}
    end

    def remote_cmd_spy_blocks
      @remote_cmd_spy_blocks ||= {}
    end

    def cmd_spy_key(cmd_str, input, given_opts)
      [cmd_str, input, given_opts]
    end

  end

end
