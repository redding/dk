require 'assert'
require 'dk/has_the_stubs'

require 'stringio'
require 'dk/config'
require 'dk/dry_runner'
require 'dk/tree_runner'
require 'dk/test_runner'

module Dk::HasTheStubs

  class SystemTests < Assert::Context
    desc "Dk::HasTheStubs"

  end

  class RunnerTests < SystemTests
    desc "used by a runner"
    setup do
      @runner_class = [
        Dk::DryRunner,
        Dk::TreeRunner,
        Dk::TestRunner
      ].sample

      # turn off the stdout logging
      @dk_config = Dk::Config.new
      @logger    = Dk::NullLogger.new
      Assert.stub(@dk_config, :dk_logger){ @logger }

      @task_class = StubTestTask
      @runner     = build_runner(@task_class)

      @cmd_str   = Factory.string
      @cmd_input = Factory.string
      @cmd_opts  = { Factory.string => Factory.string }

      @params = {
        'use_bang'  => false,
        'cmd_str'   => @cmd_str,
        'cmd_input' => @cmd_input,
        'cmd_opts'  => @cmd_opts
      }
    end

    private

    def build_runner(task_class)
      if @runner_class == Dk::TestRunner
        @runner_class.new(:logger => @logger).tap{ |r| r.task_class = task_class }
      elsif @runner_class == Dk::TreeRunner
        @runner_class.new(@dk_config, StringIO.new)
      else
        @runner_class.new(@dk_config)
      end
    end

    def run_runner(runner, task_class, params)
      if @runner_class == Dk::TestRunner
        runner.run(params)
      else
        runner.run(task_class, params)
      end
    end

    def add_stubs(runner, local)
      method = local ? :stub_cmd : :stub_ssh

      @only_cmd_stdout  = Factory.stdout
      @only_cmd_stderr  = Factory.stderr
      @only_cmd_success = Factory.boolean
      @only_cmd_spy     = nil
      @runner.send(method, @cmd_str) do |spy|
        spy.stdout     = @only_cmd_stdout
        spy.stderr     = @only_cmd_stderr
        spy.exitstatus = @only_cmd_success ? 0 : 1
        @only_cmd_spy  = spy
      end

      @with_input_cmd_stdout  = Factory.stdout
      @with_input_cmd_stderr  = Factory.stderr
      @with_input_cmd_success = Factory.boolean
      @with_input_cmd_spy     = nil
      @runner.send(method, @cmd_str, :input => @cmd_input) do |spy|
        spy.stdout          = @with_input_cmd_stdout
        spy.stderr          = @with_input_cmd_stderr
        spy.exitstatus      = @with_input_cmd_success ? 0 : 1
        @with_input_cmd_spy = spy
      end

      @with_opts_cmd_stdout  = Factory.stdout
      @with_opts_cmd_stderr  = Factory.stderr
      @with_opts_cmd_success = Factory.boolean
      @with_opts_cmd_spy     = nil
      @runner.send(method, @cmd_str, :opts => @cmd_opts) do |spy|
        spy.stdout         = @with_opts_cmd_stdout
        spy.stderr         = @with_opts_cmd_stderr
        spy.exitstatus     = @with_opts_cmd_success ? 0 : 1
        @with_opts_cmd_spy = spy
      end

      @with_all_cmd_stdout  = Factory.stdout
      @with_all_cmd_stderr  = Factory.stderr
      @with_all_cmd_success = Factory.boolean
      @with_all_cmd_spy     = nil
      @runner.send(method, @cmd_str, {
        :input => @cmd_input,
        :opts  => @cmd_opts
      }) do |spy|
        spy.stdout        = @with_all_cmd_stdout
        spy.stderr        = @with_all_cmd_stderr
        spy.exitstatus    = @with_all_cmd_success ? 0 : 1
        @with_all_cmd_spy = spy
      end
    end

  end

  class CmdStubTests < RunnerTests
    setup do
      @params.merge!('local' => true)
      add_stubs(@runner, @params['local'])
    end

    should "allow stubbing `cmd` calls" do
      task = run_runner(@runner, @task_class, @params)

      # ensure calls return the cmd spy they are stubbed with
      assert_same @only_cmd_spy,       task.only_cmd
      assert_same @with_input_cmd_spy, task.with_input_cmd
      assert_same @with_opts_cmd_spy,  task.with_opts_cmd
      assert_same @with_all_cmd_spy,   task.with_all_cmd

      # ensure the cmd spies are local spies
      assert_false @only_cmd_spy.ssh?
      assert_false @with_input_cmd_spy.ssh?
      assert_false @with_opts_cmd_spy.ssh?
      assert_false @with_all_cmd_spy.ssh?

      # ensure cmd spies are run
      assert_true @only_cmd_spy.run_called?
      assert_true @with_input_cmd_spy.run_called?
      assert_true @with_opts_cmd_spy.run_called?
      assert_true @with_all_cmd_spy.run_called?

      # ensure stubs can set stdout
      assert_equal @only_cmd_stdout,       @only_cmd_spy.stdout
      assert_equal @with_input_cmd_stdout, @with_input_cmd_spy.stdout
      assert_equal @with_opts_cmd_stdout,  @with_opts_cmd_spy.stdout
      assert_equal @with_all_cmd_stdout,   @with_all_cmd_spy.stdout

      # ensure stubs can set stderr
      assert_equal @only_cmd_stderr,       @only_cmd_spy.stderr
      assert_equal @with_input_cmd_stderr, @with_input_cmd_spy.stderr
      assert_equal @with_opts_cmd_stderr,  @with_opts_cmd_spy.stderr
      assert_equal @with_all_cmd_stderr,   @with_all_cmd_spy.stderr

      # ensure stubs can set exitstatus
      assert_equal @only_cmd_success,       @only_cmd_spy.success?
      assert_equal @with_input_cmd_success, @with_input_cmd_spy.success?
      assert_equal @with_opts_cmd_success,  @with_opts_cmd_spy.success?
      assert_equal @with_all_cmd_success,   @with_all_cmd_spy.success?
    end

    should "allow stubbing `cmd!` calls" do
      @params['use_bang'] = true
      task = run_runner(@runner, @task_class, @params)

      # ensure stubs can control whether a `cmd!` raises an error or not

      if @only_cmd_success
        assert_equal @only_cmd_spy, task.only_cmd
      else
        assert_true task.only_cmd_failed
      end

      if @with_input_cmd_success
        assert_equal @with_input_cmd_spy, task.with_input_cmd
      else
        assert_true task.with_input_cmd_failed
      end

      if @with_opts_cmd_success
        assert_equal @with_opts_cmd_spy, task.with_opts_cmd
      else
        assert_true task.with_opts_cmd_failed
      end

      if @with_all_cmd_success
        assert_equal @with_all_cmd_spy, task.with_all_cmd
      else
        assert_true task.with_all_cmd_failed
      end
    end

    should "unstub all cmd spies" do
      @runner.unstub_all_cmds
      @params['use_bang'] = Factory.boolean
      task = run_runner(@runner, @task_class, @params)

      assert_not_same @only_cmd_spy,       task.only_cmd
      assert_not_same @with_input_cmd_spy, task.with_input_cmd
      assert_not_same @with_opts_cmd_spy,  task.with_opts_cmd
      assert_not_same @with_all_cmd_spy,   task.with_all_cmd
    end

  end

  class SshStubTests < RunnerTests
    setup do
      @cmd_opts = Factory.ssh_cmd_opts
      @params.merge!({
        'local'    => false,
        'cmd_opts' => @cmd_opts
      })
      add_stubs(@runner, @params['local'])
    end

    should "allow stubbing `ssh` calls" do
      task = run_runner(@runner, @task_class, @params)

      # ensure calls return the cmd spy they are stubbed with
      assert_same @only_cmd_spy,       task.only_cmd
      assert_same @with_input_cmd_spy, task.with_input_cmd
      assert_same @with_opts_cmd_spy,  task.with_opts_cmd
      assert_same @with_all_cmd_spy,   task.with_all_cmd

      # ensure the cmd spies are remote spies
      assert_true @only_cmd_spy.ssh?
      assert_true @with_input_cmd_spy.ssh?
      assert_true @with_opts_cmd_spy.ssh?
      assert_true @with_all_cmd_spy.ssh?

      # ensure cmd spies are run
      assert_true @only_cmd_spy.run_called?
      assert_true @with_input_cmd_spy.run_called?
      assert_true @with_opts_cmd_spy.run_called?
      assert_true @with_all_cmd_spy.run_called?

      # ensure stubs can set stdout
      assert_equal @only_cmd_stdout,       @only_cmd_spy.stdout
      assert_equal @with_input_cmd_stdout, @with_input_cmd_spy.stdout
      assert_equal @with_opts_cmd_stdout,  @with_opts_cmd_spy.stdout
      assert_equal @with_all_cmd_stdout,   @with_all_cmd_spy.stdout

      # ensure stubs can set stderr
      assert_equal @only_cmd_stderr,       @only_cmd_spy.stderr
      assert_equal @with_input_cmd_stderr, @with_input_cmd_spy.stderr
      assert_equal @with_opts_cmd_stderr,  @with_opts_cmd_spy.stderr
      assert_equal @with_all_cmd_stderr,   @with_all_cmd_spy.stderr

      # ensure stubs can set exitstatus
      assert_equal @only_cmd_success,       @only_cmd_spy.success?
      assert_equal @with_input_cmd_success, @with_input_cmd_spy.success?
      assert_equal @with_opts_cmd_success,  @with_opts_cmd_spy.success?
      assert_equal @with_all_cmd_success,   @with_all_cmd_spy.success?
    end

    should "allow stubbing `ssh!` calls" do
      @params['use_bang'] = true
      task = run_runner(@runner, @task_class, @params)

      # ensure stubs can control whether a `ssh!` raises an error or not

      if @only_cmd_success
        assert_equal @only_cmd_spy, task.only_cmd
      else
        assert_true task.only_cmd_failed
      end

      if @with_input_cmd_success
        assert_equal @with_input_cmd_spy, task.with_input_cmd
      else
        assert_true task.with_input_cmd_failed
      end

      if @with_opts_cmd_success
        assert_equal @with_opts_cmd_spy, task.with_opts_cmd
      else
        assert_true task.with_opts_cmd_failed
      end

      if @with_all_cmd_success
        assert_equal @with_all_cmd_spy, task.with_all_cmd
      else
        assert_true task.with_all_cmd_failed
      end
    end

    should "unstub all cmd spies" do
      @runner.unstub_all_ssh
      @params['use_bang'] = Factory.boolean
      task = run_runner(@runner, @task_class, @params)

      assert_not_same @only_cmd_spy,       task.only_cmd
      assert_not_same @with_input_cmd_spy, task.with_input_cmd
      assert_not_same @with_opts_cmd_spy,  task.with_opts_cmd
      assert_not_same @with_all_cmd_spy,   task.with_all_cmd
    end

  end

  class StubTestTask
    include Dk::Task

    attr_reader :only_cmd, :with_input_cmd, :with_opts_cmd, :with_all_cmd
    attr_reader :only_cmd_failed, :with_input_cmd_failed
    attr_reader :with_opts_cmd_failed, :with_all_cmd_failed

    ssh_hosts 'test'

    def run!
      method = if params['local']
        params['use_bang'] ? :cmd! : :cmd
      else
        params['use_bang'] ? :ssh! : :ssh
      end

      begin
        @only_cmd = send(method, params['cmd_str'])
        @only_cmd_failed = false
      rescue CmdRunError, SSHRunError
        @only_cmd_failed = true
      end

      begin
        @with_input_cmd = send(method, params['cmd_str'], params['cmd_input'])
        @with_input_cmd_failed = false
      rescue CmdRunError, SSHRunError
        @with_input_cmd_failed = true
      end

      begin
        @with_opts_cmd = send(method, params['cmd_str'], params['cmd_opts'])
        @with_opts_cmd_failed = false
      rescue CmdRunError, SSHRunError
        @with_opts_cmd_failed = true
      end

      begin
        @with_all_cmd = send(
          method,
          params['cmd_str'],
          params['cmd_input'],
          params['cmd_opts']
        )
        @with_all_cmd_failed = false
      rescue CmdRunError, SSHRunError
        @with_all_cmd_failed = true
      end
    end

  end

end
