require 'assert'
require 'dk/task'

require 'much-plugin'
require 'dk/remote'
require 'dk/runner'

module Dk::Task

  class UnitTests < Assert::Context
    desc "Dk::Task"
    setup do
      @task_class = Class.new{ include Dk::Task }
    end
    subject{ @task_class }

    should have_imeths :description, :desc
    should have_imeths :before_callbacks, :after_callbacks
    should have_imeths :before_callback_task_classes
    should have_imeths :after_callback_task_classes
    should have_imeths :before, :after, :prepend_before, :prepend_after
    should have_imeths :ssh_hosts, :run_only_once

    should "use much-plugin" do
      assert_includes MuchPlugin, Dk::Task
    end

    should "set its description" do
      exp = Factory.string
      subject.description exp
      assert_equal exp, subject.description
      assert_equal exp, subject.desc

      exp = Factory.string
      subject.desc exp
      assert_equal exp, subject.description
      assert_equal exp, subject.desc
    end

    should "know its default callbacks" do
      assert_equal [], subject.before_callbacks
      assert_equal [], subject.after_callbacks
      assert_equal [], subject.before_callback_task_classes
      assert_equal [], subject.after_callback_task_classes
    end

    should "append callbacks" do
      task_class = Factory.string
      params     = Factory.string

      subject.before_callbacks << Factory.task_callback(Factory.string)
      subject.before(task_class, params)
      assert_equal task_class, subject.before_callbacks.last.task_class
      assert_equal params,     subject.before_callbacks.last.params

      exp = subject.before_callbacks.map(&:task_class)
      assert_equal exp, subject.before_callback_task_classes

      subject.after_callbacks << Factory.task_callback(Factory.string)
      subject.after(task_class, params)
      assert_equal task_class, subject.after_callbacks.last.task_class
      assert_equal params,     subject.after_callbacks.last.params

      exp = subject.after_callbacks.map(&:task_class)
      assert_equal exp, subject.after_callback_task_classes
    end

    should "prepend callbacks" do
      task_class = Factory.string
      params     = Factory.string

      subject.before_callbacks << Factory.task_callback(Factory.string)
      subject.prepend_before(task_class, params)
      assert_equal task_class, subject.before_callbacks.first.task_class
      assert_equal params,     subject.before_callbacks.first.params

      exp = subject.before_callbacks.map(&:task_class)
      assert_equal exp, subject.before_callback_task_classes

      subject.after_callbacks << Factory.task_callback(Factory.string)
      subject.prepend_after(task_class, params)
      assert_equal task_class, subject.after_callbacks.first.task_class
      assert_equal params,     subject.after_callbacks.first.params

      exp = subject.after_callbacks.map(&:task_class)
      assert_equal exp, subject.after_callback_task_classes
    end

    should "know its ssh hosts proc" do
      assert_kind_of Proc, subject.ssh_hosts
      assert_nil subject.ssh_hosts.call

      hosts = Factory.hosts

      subject.ssh_hosts hosts
      assert_kind_of Proc, subject.ssh_hosts
      assert_equal hosts, subject.ssh_hosts.call

      subject.ssh_hosts{ hosts }
      assert_kind_of Proc, subject.ssh_hosts
      assert_equal hosts, subject.ssh_hosts.call
    end

    should "set whether it should run only once" do
      assert_nil subject.run_only_once

      value = [true, Factory.string, Factory.integer].sample
      subject.run_only_once value
      assert_true subject.run_only_once

      value = false
      subject.run_only_once value
      assert_false subject.run_only_once
    end

  end

  class InitTests < UnitTests
    include Dk::Task::TestHelpers

    desc "when init"
    setup do
      @default_ssh_cmd_opts =  {
        :ssh_args      => Factory.string,
        :host_ssh_args => { Factory.string => Factory.string },
        :hosts         => Factory.hosts
      }

      @hosts_group_name = Factory.string
      @runner_ssh_hosts = { @hosts_group_name => @default_ssh_cmd_opts[:hosts] }
      @task_class.ssh_hosts @hosts_group_name
      @runner = test_runner(@task_class, {
        :params        => { Factory.string => Factory.string },
        :ssh_hosts     => @runner_ssh_hosts,
        :ssh_args      => @default_ssh_cmd_opts[:ssh_args],
        :host_ssh_args => @default_ssh_cmd_opts[:host_ssh_args]
      })
      @task = @runner.task
    end
    subject{ @task }

    should have_imeths :dk_run, :run!, :dk_dsl_ssh_hosts

    should "not implement its run! method" do
      assert_raises NotImplementedError do
        subject.run!
      end
    end

    should "know its configured DSL ssh hosts" do
      assert_equal @hosts_group_name, subject.dk_dsl_ssh_hosts

      hosts      = Factory.hosts
      task_class = Class.new{ include Dk::Task; ssh_hosts hosts; }
      task       = test_task(task_class)
      assert_equal hosts, task.dk_dsl_ssh_hosts

      task_class = Class.new{ include Dk::Task }
      task       = test_task(task_class)
      assert_nil task.dk_dsl_ssh_hosts
    end

    should "know if it is equal to another task" do
      task = @task_class.new(@runner)
      assert_equal task, subject

      task = Class.new{ include Dk::Task }.new(@runner)
      assert_not_equal task, subject
    end

  end

  class RunTests < InitTests
    desc "and run"
    setup do
      # build a call orders object to pass around to the callback tasks for
      # shared state call order
      @call_orders = CallOrders.new

      # build a base runner and task manually so the callback tasks actually
      # run (b/c the test runner doesn't run callbacks)
      @runner = Dk::Runner.new({
        :params                   => { 'call_orders' => @call_orders },
        :before_callbacks         => {
          CallbacksTask => [
            Callback.new(CallbackTask, 'callback' => 'runner_before')
          ]
        },
        :prepend_before_callbacks => {
          CallbacksTask => [
            Callback.new(CallbackTask, 'callback' => 'runner_prepend_before')
          ]
        },
        :after_callbacks          => {
          CallbacksTask => [
            Callback.new(CallbackTask, 'callback' => 'runner_after')
          ]
        },
        :prepend_after_callbacks  => {
          CallbacksTask => [
            Callback.new(CallbackTask, 'callback' => 'runner_prepend_after')
          ]
        }
      })

      # use this CallbacksTask that has a bunch of callbacks configured so we
      # can test callback run and call order.  Also this CallbacksTask uses
      # callback params which will test all the params handling in callbacks
      # and the task running behavior.
      @task = CallbacksTask.new(@runner)

      @task.dk_run
    end

    should "call `run!` and run any callback tasks" do
      assert_equal  1, @call_orders.runner_prepend_before_call_order
      assert_equal  2, @call_orders.prepend_before_call_order
      assert_equal  3, @call_orders.first_before_call_order
      assert_equal  4, @call_orders.second_before_call_order
      assert_equal  5, @call_orders.runner_before_call_order
      assert_equal  6, @call_orders.run_call_order
      assert_equal  7, @call_orders.runner_prepend_after_call_order
      assert_equal  8, @call_orders.prepend_after_call_order
      assert_equal  9, @call_orders.first_after_call_order
      assert_equal 10, @call_orders.second_after_call_order
      assert_equal 11, @call_orders.runner_after_call_order
    end

  end

  class RunOnlyOnceTests < RunTests
    desc "with run only once set"
    setup do
      CallbacksTask.run_only_once false
    end
    teardown do
      CallbacksTask.run_only_once false
    end

    # the logic controlling this is in the runner, however this test exists
    # as sort of a 'system-y' test to ensure the logic at the task level
    should "run only once" do
      @call_orders.reset
      @runner.run(CallbacksTask)

      # should run the task even though it has already been run by the runner
      assert_equal 6, @call_orders.run_call_order

      CallbacksTask.run_only_once true
      @call_orders.reset
      @runner.run(CallbacksTask)

      # should not run the task since it has already been run by the runner
      assert_nil @call_orders.run_call_order
    end

  end

  class RunTaskPrivateHelperTests < InitTests
    setup do
      @runner_run_task_called_with = nil
      Assert.stub(@runner, :run_task){ |*args| @runner_run_task_called_with = args }
    end

    should "run other tasks by calling the runner's `run_task` method" do
      other_task_class  = Class.new{ include Dk::Task }
      other_task_params = { Factory.string => Factory.string }
      subject.instance_eval{ run_task(other_task_class, other_task_params) }

      exp = [other_task_class, other_task_params]
      assert_equal exp, @runner_run_task_called_with
    end

  end

  class CmdPrivateHelpersTests < InitTests

    should "run local cmds, calling to the runner" do
      runner_cmd_called_with = nil
      Assert.stub(@runner, :cmd) do |*args|
        runner_cmd_called_with = args
        Assert.stub_send(@runner, :cmd, *args)
      end

      cmd_str   = Factory.string
      cmd_input = Factory.string
      cmd_opts  = { Factory.string => Factory.string }

      subject.instance_eval{ cmd(cmd_str, cmd_input, cmd_opts) }
      exp = [cmd_str, cmd_input, cmd_opts]
      assert_equal exp, runner_cmd_called_with

      subject.instance_eval{ cmd(cmd_str) }
      exp = [cmd_str, nil, nil]
      assert_equal exp, runner_cmd_called_with

      subject.instance_eval{ cmd(cmd_str, cmd_input) }
      exp = [cmd_str, cmd_input, nil]
      assert_equal exp, runner_cmd_called_with

      subject.instance_eval{ cmd(cmd_str, cmd_opts) }
      exp = [cmd_str, nil, cmd_opts]
      assert_equal exp, runner_cmd_called_with

      subject.instance_eval{ cmd!(cmd_str, cmd_input, cmd_opts) }
      exp = [cmd_str, cmd_input, cmd_opts]
      assert_equal exp, runner_cmd_called_with

      subject.instance_eval{ cmd!(cmd_str) }
      exp = [cmd_str, nil, nil]
      assert_equal exp, runner_cmd_called_with

      subject.instance_eval{ cmd!(cmd_str, cmd_input) }
      exp = [cmd_str, cmd_input, nil]
      assert_equal exp, runner_cmd_called_with

      subject.instance_eval{ cmd!(cmd_str, cmd_opts) }
      exp = [cmd_str, nil, cmd_opts]
      assert_equal exp, runner_cmd_called_with
    end

    should "run local cmds and error if not successful" do
      runner_cmd_called_with = nil
      Assert.stub(@runner, :cmd) do |*args|
        runner_cmd_called_with = args
        Assert.stub_send(@runner, :cmd, *args).tap do |cmd_spy|
          Assert.stub(cmd_spy, :success?){ false }
        end
      end

      cmd_str   = Factory.string
      cmd_input = Factory.string
      cmd_opts  = { Factory.string => Factory.string }

      err = assert_raises(CmdRunError) do
        subject.instance_eval{ cmd!(cmd_str, cmd_input, cmd_opts) }
      end

      exp = "error running `#{cmd_str}`"
      assert_equal exp, err.message

      exp = [cmd_str, cmd_input, cmd_opts]
      assert_equal exp, runner_cmd_called_with
    end

  end

  class SSHPrivateHelpersTests < InitTests

    should "run ssh cmds, calling to the runner" do
      runner_ssh_called_with = nil
      Assert.stub(@runner, :ssh) do |*args|
        runner_ssh_called_with = args
        Assert.stub_send(@runner, :ssh, *args)
      end

      cmd_str        = Factory.string
      cmd_input      = Factory.string
      cmd_given_opts = Factory.ssh_cmd_opts

      exp_cmd_ssh_opts = @default_ssh_cmd_opts.merge(cmd_given_opts)

      subject.instance_eval{ ssh(cmd_str, cmd_input, cmd_given_opts) }
      exp = [cmd_str, cmd_input, cmd_given_opts, exp_cmd_ssh_opts]
      assert_equal exp, runner_ssh_called_with

      subject.instance_eval{ ssh(cmd_str) }
      exp = [cmd_str, nil, nil, @default_ssh_cmd_opts]
      assert_equal exp, runner_ssh_called_with

      subject.instance_eval{ ssh(cmd_str, cmd_input) }
      exp = [cmd_str, cmd_input, nil, @default_ssh_cmd_opts]
      assert_equal exp, runner_ssh_called_with

      subject.instance_eval{ ssh(cmd_str, cmd_given_opts) }
      exp = [cmd_str, nil, cmd_given_opts, exp_cmd_ssh_opts]
      assert_equal exp, runner_ssh_called_with

      subject.instance_eval{ ssh!(cmd_str, cmd_input, cmd_given_opts) }
      exp = [cmd_str, cmd_input, cmd_given_opts, exp_cmd_ssh_opts]
      assert_equal exp, runner_ssh_called_with

      subject.instance_eval{ ssh!(cmd_str) }
      exp = [cmd_str, nil, nil, @default_ssh_cmd_opts]
      assert_equal exp, runner_ssh_called_with

      subject.instance_eval{ ssh!(cmd_str, cmd_input) }
      exp = [cmd_str, cmd_input, nil, @default_ssh_cmd_opts]
      assert_equal exp, runner_ssh_called_with

      subject.instance_eval{ ssh!(cmd_str, cmd_given_opts) }
      exp = [cmd_str, nil, cmd_given_opts, exp_cmd_ssh_opts]
      assert_equal exp, runner_ssh_called_with
    end

    should "build ssh cmd strs" do
      remote_ssh_called_with = nil
      Assert.stub(Dk::Remote, :ssh_cmd_str){ |*args| remote_ssh_called_with = args }

      cmd_str  = Factory.string
      cmd_opts = {
        :host          => Factory.string,
        :ssh_args      => Factory.string,
        :host_ssh_args => { Factory.string => Factory.string }
      }
      subject.instance_eval{ ssh_cmd_str(cmd_str, cmd_opts) }

      exp = [cmd_str, cmd_opts[:host], cmd_opts[:ssh_args], cmd_opts[:host_ssh_args]]
      assert_equal exp, remote_ssh_called_with
    end

    should "force any given hosts value to an Array" do
      runner_ssh_called_with_opts = nil
      Assert.stub(@runner, :ssh){ |_, _, _, o| runner_ssh_called_with_opts = o }

      host = Factory.string
      subject.instance_eval{ ssh(Factory.string, :hosts => host) }

      exp = [host]
      assert_equal exp, runner_ssh_called_with_opts[:hosts]
    end

    should "run ssh cmds and error if not successful" do
      runner_ssh_called_with = nil
      Assert.stub(@runner, :ssh) do |*args|
        runner_ssh_called_with = args
        Assert.stub_send(@runner, :ssh, *args).tap do |cmd_spy|
          Assert.stub(cmd_spy, :success?){ false }
        end
      end

      cmd_str        = Factory.string
      cmd_input      = Factory.string
      cmd_given_opts = Factory.ssh_cmd_opts

      err = assert_raises(SSHRunError) do
        subject.instance_eval{ ssh!(cmd_str, cmd_input, cmd_given_opts) }
      end

      exp = "error running `#{cmd_str}` over ssh"
      assert_equal exp, err.message

      exp_cmd_ssh_opts = @default_ssh_cmd_opts.merge(cmd_given_opts)
      exp = [cmd_str, cmd_input, cmd_given_opts, exp_cmd_ssh_opts]
      assert_equal exp, runner_ssh_called_with
    end

    should "use the task's ssh hosts if none are specified" do
      task_class = Class.new{ include Dk::Task; ssh_hosts Factory.hosts; }
      runner     = test_runner(task_class)
      task       = runner.task

      runner_ssh_called_with_opts = nil
      Assert.stub(runner, :ssh){ |_, _, _, o| runner_ssh_called_with_opts = o }

      task.instance_eval{ ssh(Factory.string) }
      assert_equal task_class.ssh_hosts.call, runner_ssh_called_with_opts[:hosts]
    end

    should "lookup the task's ssh hosts from the runner hosts" do
      hosts      = Factory.hosts
      task_class = Class.new{ include Dk::Task; ssh_hosts Factory.string; }

      runner = test_runner(task_class, :ssh_hosts => {
        task_class.ssh_hosts.call => hosts
      })
      task = runner.task

      runner_ssh_called_with_opts = nil
      Assert.stub(runner, :ssh){ |_, _, _, o| runner_ssh_called_with_opts = o }

      task.instance_eval{ ssh(Factory.string) }
      assert_equal hosts, runner_ssh_called_with_opts[:hosts]
    end

    should "instance eval the task's ssh hosts" do
      hosts      = Factory.hosts
      app_hosts  = Factory.string
      task_class = Class.new{ include Dk::Task; ssh_hosts{ params['app_hosts'] }; }

      runner = test_runner(task_class, {
        :params    => { 'app_hosts' => app_hosts },
        :ssh_hosts => { app_hosts => hosts }
      })
      task = runner.task

      runner_ssh_called_with_opts = nil
      Assert.stub(runner, :ssh){ |_, _, _, o| runner_ssh_called_with_opts = o }

      task.instance_eval{ ssh(Factory.string) }
      assert_equal hosts, runner_ssh_called_with_opts[:hosts]
    end

    should "lookup given hosts from the runner hosts" do
      hosts      = Factory.hosts
      hosts_name = Factory.string
      task_class = Class.new{ include Dk::Task }

      runner = test_runner(task_class, :ssh_hosts => {
        hosts_name => hosts
      })
      task = runner.task

      runner_ssh_called_with_opts = nil
      Assert.stub(runner, :ssh){ |_, _, _, o| runner_ssh_called_with_opts = o }

      task.instance_eval{ ssh(Factory.string, :hosts => hosts_name) }
      assert_equal hosts, runner_ssh_called_with_opts[:hosts]
    end

    should "use the runner's ssh args if none are given" do
      args       = Factory.string
      task_class = Class.new{ include Dk::Task }
      runner     = test_runner(task_class, :ssh_args => args)
      task       = runner.task

      runner_ssh_called_with_opts = nil
      Assert.stub(runner, :ssh){ |_, _, _, o| runner_ssh_called_with_opts = o }

      task.instance_eval{ ssh(Factory.string) }
      assert_equal args, runner_ssh_called_with_opts[:ssh_args]
    end

    should "use the runner's ssh args to build ssh cmd strs if none are given" do
      ssh_args   = Factory.string
      task_class = Class.new{ include Dk::Task }
      runner     = test_runner(task_class, :ssh_args => ssh_args)
      task       = runner.task

      remote_ssh_called_with = nil
      Assert.stub(Dk::Remote, :ssh_cmd_str){ |*args| remote_ssh_called_with = args }

      cmd_str  = Factory.string
      cmd_opts = {
        :host          => Factory.string,
        :host_ssh_args => { Factory.string => Factory.string }
      }
      task.instance_eval{ ssh_cmd_str(cmd_str, cmd_opts) }

      exp = [cmd_str, cmd_opts[:host], ssh_args, cmd_opts[:host_ssh_args]]
      assert_equal exp, remote_ssh_called_with
    end

    should "use the runner's host ssh args if none are given" do
      args       = { Factory.string => Factory.string }
      task_class = Class.new{ include Dk::Task }
      runner     = test_runner(task_class, :host_ssh_args => args)
      task       = runner.task

      runner_ssh_called_with_opts = nil
      Assert.stub(runner, :ssh){ |_, _, _, o| runner_ssh_called_with_opts = o }

      task.instance_eval{ ssh(Factory.string) }
      assert_equal args, runner_ssh_called_with_opts[:host_ssh_args]
    end

    should "use the runner's host ssh args to build cmd strs if none are given" do
      ssh_args   = { Factory.string => Factory.string }
      task_class = Class.new{ include Dk::Task }
      runner     = test_runner(task_class, :host_ssh_args => ssh_args)
      task       = runner.task

      remote_ssh_called_with = nil
      Assert.stub(Dk::Remote, :ssh_cmd_str){ |*args| remote_ssh_called_with = args }

      cmd_str  = Factory.string
      cmd_opts = {
        :host     => Factory.string,
        :ssh_args => Factory.string
      }
      task.instance_eval{ ssh_cmd_str(cmd_str, cmd_opts) }

      exp = [cmd_str, cmd_opts[:host], cmd_opts[:ssh_args], ssh_args]
      assert_equal exp, remote_ssh_called_with
    end

  end

  class ParamsPrivateHelpersTests < InitTests
    setup do
      @task_params = { Factory.string => Factory.string }
    end

    should "call to the runner for `params`" do
      p = @runner.params.keys.first
      assert_equal @runner.params[p], subject.instance_eval{ params[p] }

      assert_raises(ArgumentError) do
        subject.instance_eval{ params[Factory.string] }
      end
    end

    should "call to the runner for `set_param`" do
      set_param_called_with = nil
      Assert.stub(@runner, :set_param){ |*args| set_param_called_with = args }

      key, value = Factory.string, Factory.string
      subject.instance_eval{ set_param(key, value) }

      exp = [key, value]
      assert_equal exp, set_param_called_with
    end

    should "merge any given task params" do
      task_w_params = @task_class.new(@runner, @task_params)

      p = @runner.params.keys.first
      assert_equal @runner.params[p], task_w_params.instance_eval{ params[p] }

      p = @task_params.keys.first
      assert_equal @task_params[p], task_w_params.instance_eval{ params[p] }

      assert_raises(ArgumentError) do
        task_w_params.instance_eval{ params[Factory.string] }
      end
    end

    should "only write task params and not write runner params" do
      p   = Factory.string
      val = Factory.string
      subject.instance_eval{ params[p] = val }

      assert_equal val, subject.instance_eval{ params[p] }
      assert_raises(ArgumentError){ @runner.params[p] }
    end

    should "set a runner (and task) param using `set_param`" do
      p   = Factory.string
      val = Factory.string
      subject.instance_eval{ set_param(p, val) }

      assert_equal val, subject.instance_eval{ params[p] }
      assert_equal val, @runner.params[p]
    end

    should "know if either a task or runner param is set" do
      task_w_params = @task_class.new(@runner, @task_params)

      p = @runner.params.keys.first
      assert_true task_w_params.instance_eval{ param?(p) }

      p = @task_params.keys.first
      assert_true task_w_params.instance_eval{ param?(p) }

      assert_false task_w_params.instance_eval{ param?(Factory.string) }
    end

  end

  class CallbackPrivateHelpersTests < InitTests

    should "append callbacks" do
      subj   = Factory.string
      cb     = Factory.string
      params = Factory.string

      @runner.add_task_callback('before', Factory.string, Factory.string, {})
      subject.instance_eval{ before(subj, cb, params) }
      callback = @runner.task_callbacks('before', subj).last
      assert_equal cb,     callback.task_class
      assert_equal params, callback.params

      @runner.add_task_callback('after', Factory.string, Factory.string, {})
      subject.instance_eval{ after(subj, cb, params) }
      callback = @runner.task_callbacks('after', subj).last
      assert_equal cb,     callback.task_class
      assert_equal params, callback.params
    end

    should "prepend callbacks" do
      subj   = Factory.string
      cb     = Factory.string
      params = Factory.string

      @runner.add_task_callback('prepend_before', Factory.string, Factory.string, {})
      subject.instance_eval{ prepend_before(subj, cb, params) }
      callback = @runner.task_callbacks('prepend_before', subj).first
      assert_equal cb,     callback.task_class
      assert_equal params, callback.params

      @runner.add_task_callback('prepend_after', Factory.string, Factory.string, {})
      subject.instance_eval{ prepend_after(subj, cb, params) }
      callback = @runner.task_callbacks('prepend_after', subj).first
      assert_equal cb,     callback.task_class
      assert_equal params, callback.params
    end

  end

  class SSHHostsPrivateHelpersTests < InitTests

    should "know and set its runner's ssh hosts" do
      group_name = Factory.string
      hosts      = Factory.hosts

      assert_equal @runner.ssh_hosts, subject.instance_eval{ ssh_hosts }
      assert_nil subject.instance_eval{ ssh_hosts(group_name) }

      assert_equal hosts, subject.instance_eval{ ssh_hosts(group_name, hosts) }
      assert_equal hosts, subject.instance_eval{ ssh_hosts(group_name) }

      exp = @runner_ssh_hosts.merge(group_name => hosts)
      assert_equal exp,               @runner.ssh_hosts
      assert_equal @runner.ssh_hosts, subject.instance_eval{ ssh_hosts }
    end

  end

  class HaltPrivateHelperTests < InitTests
    setup do
      # build a runs object to pass around to the callback tasks for
      # shared state of what has been run
      @runs = Runs.new([])

      # build a base runner and task manually so the callback tasks actually
      # run (b/c the test runner doesn't run callbacks)
      @runner = Dk::Runner.new({
        :params => { 'runs' => @runs }
      })

      # use this HaltTask that has a bunch of callbacks configured so we can
      # test callback halt handling.
      @task = HaltTask.new(@runner)

      @task.dk_run
    end

    should "halt just the run! execution (not the callbacks) with `halt`" do
      exp = ['first_before', 'run_before_halt', 'second_after']
      assert_equal exp, @runs.list
    end

  end

  class LogPrivateHelpersTests < InitTests
    setup do
      @runner_log_info_called_with  = nil
      Assert.stub(@runner, :log_info){ |*args| @runner_log_info_called_with = args }

      @runner_log_debug_called_with = nil
      Assert.stub(@runner, :log_debug){ |*args| @runner_log_debug_called_with = args }

      @runner_log_error_called_with = nil
      Assert.stub(@runner, :log_error){ |*args| @runner_log_error_called_with = args }
    end

    should "log by calling the runner's log methods" do
      msg = Factory.string

      subject.instance_eval{ log_info(msg) }
      assert_equal [msg], @runner_log_info_called_with

      subject.instance_eval{ log_debug(msg) }
      assert_equal [msg], @runner_log_debug_called_with

      subject.instance_eval{ log_error(msg) }
      assert_equal [msg], @runner_log_error_called_with
    end

  end

  class TestHelpersTests < UnitTests
    desc "TestHelpers"
    setup do
      @args = {
        :params => { Factory.string => Factory.string }
      }

      context_class = Class.new{ include Dk::Task::TestHelpers }
      @context = context_class.new
    end
    subject{ @context }

    should have_imeths :test_runner, :test_task, :ssh_cmd_str

    should "build a test runner for a given handler class" do
      runner = subject.test_runner(@task_class, @args)

      assert_kind_of Dk::TestRunner, runner
      assert_equal @task_class,      runner.task_class
      assert_equal @args[:params],   runner.params
    end

    should "return an initialized task instance" do
      task = subject.test_task(@task_class, @args)
      assert_kind_of @task_class, task

      exp = subject.test_runner(@task_class, @args).task
      assert_equal exp, task
    end

    should "build task ssh cmd strs" do
      task     = subject.test_task(@task_class)
      cmd_str  = Factory.string
      cmd_opts = {
        :host          => Factory.string,
        :ssh_args      => Factory.string,
        :host_ssh_args => { Factory.string => Factory.string }
      }

      exp = task.instance_eval{ ssh_cmd_str(cmd_str, cmd_opts) }
      assert_equal exp, subject.ssh_cmd_str(task, cmd_str, cmd_opts)
    end

  end

  class CallOrders
    attr_reader :first_before_call_order, :second_before_call_order
    attr_reader :prepend_before_call_order
    attr_reader :runner_prepend_before_call_order
    attr_reader :runner_before_call_order
    attr_reader :first_after_call_order, :second_after_call_order
    attr_reader :prepend_after_call_order
    attr_reader :runner_prepend_after_call_order
    attr_reader :runner_after_call_order
    attr_reader :run_call_order

    def first_before;          @first_before_call_order          = next_call_order; end
    def second_before;         @second_before_call_order         = next_call_order; end
    def prepend_before;        @prepend_before_call_order        = next_call_order; end
    def runner_prepend_before; @runner_prepend_before_call_order = next_call_order; end
    def runner_before;         @runner_before_call_order         = next_call_order; end
    def first_after;           @first_after_call_order           = next_call_order; end
    def second_after;          @second_after_call_order          = next_call_order; end
    def prepend_after;         @prepend_after_call_order         = next_call_order; end
    def runner_prepend_after;  @runner_prepend_after_call_order  = next_call_order; end
    def runner_after;          @runner_after_call_order          = next_call_order; end

    def run; @run_call_order = next_call_order; end

    def reset
      @first_before_call_order          = nil
      @second_before_call_order         = nil
      @prepend_before_call_order        = nil
      @runner_prepend_before_call_order = nil
      @runner_before_call_order         = nil
      @first_after_call_order           = nil
      @second_after_call_order          = nil
      @prepend_after_call_order         = nil
      @runner_prepend_after_call_order  = nil
      @runner_after_call_order          = nil
      @run_call_order                   = nil
      @order                            = nil
    end

    private

    def next_call_order
      @order ||= 0
      @order += 1
    end
  end

  class CallbackTask
    include Dk::Task

    def run!
      params['call_orders'].send(params['callback'])
    end
  end

  class CallbacksTask
    include Dk::Task

    before         CallbackTask, 'callback' => 'first_before'
    before         CallbackTask, 'callback' => 'second_before'
    prepend_before CallbackTask, 'callback' => 'prepend_before'

    after         CallbackTask, 'callback' => 'first_after'
    after         CallbackTask, 'callback' => 'second_after'
    prepend_after CallbackTask, 'callback' => 'prepend_after'

    run_only_once false

    def run!
      params['call_orders'].run
    end
  end

  Runs = Struct.new(:list)

  class HaltCallbackTask
    include Dk::Task

    def run!
      halt if params.key?('halt')
      params['runs'].list << params['run']
    end
  end

  class HaltTask
    include Dk::Task

    before HaltCallbackTask, 'run' => 'first_before'
    before HaltCallbackTask, 'run' => 'second_before', 'halt' => true
    after  HaltCallbackTask, 'run' => 'first_after', 'halt' => true
    after  HaltCallbackTask, 'run' => 'second_after'

    def run!
      params['runs'].list << 'run_before_halt'
      halt
      params['runs'].list << 'run_after_halt'
    end
  end

end
