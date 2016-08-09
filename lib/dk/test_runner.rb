require 'dk/has_the_runs'
require 'dk/has_the_stubs'
require 'dk/local'
require 'dk/remote'
require 'dk/runner'
require 'dk/task_run'

module Dk

  class TestRunner < Runner
    include HasTheRuns
    include HasTheStubs

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

    private

    def has_the_stubs_build_local_cmd(cmd_str, given_opts)
      Local::CmdSpy.new(cmd_str, given_opts)
    end

    def has_the_stubs_build_remote_cmd(cmd_str, ssh_opts)
      Remote::CmdSpy.new(cmd_str, ssh_opts)
    end

  end

end
