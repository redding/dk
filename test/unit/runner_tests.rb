require 'assert'
require 'dk/runner'

require 'dk/config'
require 'dk/has_set_param'
require 'dk/has_ssh_opts'
require 'dk/local'
require 'dk/null_logger'
require 'dk/remote'
require 'dk/task'

class Dk::Runner

  class UnitTests < Assert::Context
    desc "Dk::Runner"
    setup do
      @runner_class = Dk::Runner
    end
    subject{ @runner_class }

    should "include HasSetParam" do
      assert_includes Dk::HasSetParam, subject
    end

    should "include HasSSHOpts" do
      assert_includes Dk::HasSSHOpts, subject
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @args = {
        :params => { Factory.string => Factory.string },
        :logger => Dk::NullLogger.new
      }
      @runner = @runner_class.new(@args)
    end
    subject{ @runner }

    should have_readers :params, :logger
    should have_imeths :task_callbacks, :task_callback_task_classes
    should have_imeths :add_task_callback
    should have_imeths :run, :run_task
    should have_imeths :log_info, :log_debug, :log_error, :log_task_run
    should have_imeths :cmd, :ssh
    should have_imeths :has_run_task?, :pretty_run_time

    should "know its attrs" do
      assert_equal @args[:params], subject.params
      assert_equal @args[:logger], subject.logger
    end

    should "default its attrs" do
      runner = @runner_class.new

      assert_equal Hash.new, runner.params

      assert_equal [], runner.task_callbacks('before',         Factory.string)
      assert_equal [], runner.task_callbacks('prepend_before', Factory.string)
      assert_equal [], runner.task_callbacks('after',          Factory.string)
      assert_equal [], runner.task_callbacks('prepend_after',  Factory.string)

      assert_equal Dk::Config::DEFAULT_SSH_HOSTS,     runner.ssh_hosts
      assert_equal Dk::Config::DEFAULT_SSH_ARGS,      runner.ssh_args
      assert_equal Dk::Config::DEFAULT_HOST_SSH_ARGS, runner.host_ssh_args

      assert_instance_of Dk::NullLogger, @runner_class.new.logger
    end

    should "use params that complain when accessing missing keys" do
      key = Factory.string
      assert_raises(ArgumentError){ subject.params[key] }

      subject.params[key] = Factory.string
      assert_nothing_raised{ subject.params[key] }
    end

    should "stringify the params passed to it" do
      key, value = Factory.string.to_sym, Factory.string
      params = { key => [{ key => value }] }
      runner = @runner_class.new(:params => params)

      exp = { key.to_s => [{ key.to_s => value }] }
      assert_equal exp, runner.params
    end

    should "lookup any given task callbacks by name and task class" do
      name = ['before', 'prepend_before', 'after', 'prepend_after'].sample

      task_class = Factory.string
      callbacks  = Factory.integer(3).times.map{ Dk::Task::Callback.new(Factory.string) }
      runner = @runner_class.new("#{name}_callbacks".to_sym => { task_class => callbacks })

      assert_equal callbacks, runner.task_callbacks(name, task_class)

      exp = callbacks.map(&:task_class)
      assert_equal exp, runner.task_callback_task_classes(name, task_class)
    end

    should "add task callbacks by name and task class" do
      name = ['before', 'prepend_before', 'after', 'prepend_after'].sample

      subject         = Factory.string
      callback        = Factory.string
      callback_params = { Factory.string => Factory.string }

      runner = @runner_class.new
      runner.add_task_callback(name, subject, callback, callback_params)

      exp = [Dk::Task::Callback.new(callback, callback_params)]
      assert_equal exp,        runner.task_callbacks(name, subject)
      assert_equal [callback], runner.task_callback_task_classes(name, subject)
    end

    should "build and run a given task class, honoring any run only once setting" do
      params = { Factory.string => Factory.string }

      task = subject.run(TestTask)
      assert_true task.run_called
      assert_equal Hash.new, task.run_params

      task = subject.run(TestTask, params)
      assert_true task.run_called
      assert_equal params, task.run_params

      task = subject.run_task(TestTask)
      assert_true task.run_called
      assert_equal Hash.new, task.run_params

      task = subject.run_task(TestTask, params)
      assert_true task.run_called
      assert_equal params, task.run_params

      TestTask.run_only_once(true)

      task = subject.run(TestTask)
      assert_nil task.run_called
      assert_nil task.run_params

      task = subject.run(TestTask, params)
      assert_nil task.run_called
      assert_nil task.run_params

      task = subject.run_task(TestTask)
      assert_nil task.run_called
      assert_nil task.run_params

      task = subject.run_task(TestTask, params)
      assert_nil task.run_called
      assert_nil task.run_params
    end

    should "call to its logger for its log_{info|debug|error} methods" do
      logger_info_called_with = nil
      Assert.stub(@args[:logger], :info){ |*args| logger_info_called_with = args }

      logger_debug_called_with = nil
      Assert.stub(@args[:logger], :debug){ |*args| logger_debug_called_with = args }

      logger_error_called_with = nil
      Assert.stub(@args[:logger], :error){ |*args| logger_error_called_with = args }

      msg = Factory.string

      subject.log_info msg
      assert_equal [msg], logger_info_called_with

      subject.log_debug msg
      assert_equal [msg], logger_debug_called_with

      subject.log_error msg
      assert_equal [msg], logger_error_called_with
    end

    should "log the start/finish of task runs, including their run time" do
      logger_info_calls = []
      Assert.stub(@args[:logger], :info){ |*args| logger_info_calls << args }

      pretty_run_time = Factory.string
      Assert.stub(subject, :pretty_run_time){ pretty_run_time }

      task_class = Class.new{ include Dk::Task; def run!; end }
      subject.log_task_run(task_class){}

      exp = [
        ["> #{task_class} ..."],
        ["  ... #{task_class} (#{pretty_run_time})"]
      ]
      assert_equal exp, logger_info_calls
    end

    should "know if it has run a task or not" do
      assert_false subject.has_run_task?(TestTask)
      subject.run(TestTask)
      assert_true subject.has_run_task?(TestTask)

      task_class = Class.new{ include Dk::Task; def run!; end }
      assert_false subject.has_run_task?(task_class)
      subject.run_task(task_class)
      assert_true subject.has_run_task?(task_class)
    end

    should "know how to format raw run times and make them 'pretty'" do
      run_time = Factory.float(1.0)
      exp = "#{(run_time * 10_000).round / 10.0}ms"
      assert_equal exp, subject.pretty_run_time(run_time)

      run_time = Factory.float(10.0) + 1.0
      exp = "#{run_time / 60}:#{(run_time % 60).to_s.rjust(2, '0')}s"
      assert_equal exp, subject.pretty_run_time(run_time)
    end

  end

  class CmdSetupTests < UnitTests
    setup do
      @cmd_str        = Factory.string
      @cmd_input      = Factory.string
      @cmd_given_opts = { Factory.string => Factory.string }

      @log_out = ""
      logger = Logger.new(StringIO.new(@log_out))
      logger.formatter = proc do |severity, datetime, progname, msg|
        "#{severity} -- #{msg}\n"
      end
      @runner_opts = { :logger => logger }
    end
    subject{ @runner }

  end

  class CmdTests < CmdSetupTests
    desc "running cmds"
    setup do
      @local_cmd = nil
      @local_cmd_new_called_with = nil
      Assert.stub(Dk::Local::Cmd, :new) do |*args|
        @local_cmd_new_called_with = args
        @local_cmd = Dk::Local::CmdSpy.new(*args).tap do |cmd_spy|
          cmd_spy.stdout = Factory.stdout
        end
      end

      @runner = @runner_class.new(@runner_opts)
    end

    should "build, log and run local cmds" do
      @runner.cmd(@cmd_str, @cmd_input, @cmd_given_opts)

      exp = [@cmd_str, @cmd_given_opts]
      assert_equal exp, @local_cmd_new_called_with

      assert_not_nil @local_cmd
      assert_true @local_cmd.run_called?
      assert_equal @cmd_input, @local_cmd.run_input

      assert_equal exp_log_output(@local_cmd), @log_out
    end

    private

    def exp_log_output(cmd)
      ( ["DEBUG -- #{cmd.cmd_str}\n"] +
        cmd.output_lines.map{ |ol| "DEBUG -- #{ol.line}\n" }
      ).join("")
    end

  end

  class SSHCmdTests < CmdSetupTests
    desc "running ssh cmds"
    setup do
      @cmd_ssh_opts = { :hosts => Factory.hosts }

      @remote_cmd = nil
      @remote_cmd_new_called_with = nil
      Assert.stub(Dk::Remote::Cmd, :new) do |*args|
        @remote_cmd_new_called_with = args
        @remote_cmd = Dk::Remote::CmdSpy.new(*args).tap do |cmd_spy|
          cmd_spy.stdout = Factory.stdout
        end
      end

      @runner = @runner_class.new(@runner_opts)
    end

    should "build, log and run remote cmds" do
      @runner.ssh(@cmd_str, @cmd_input, @cmd_given_opts, @cmd_ssh_opts)

      exp = [@cmd_str, @cmd_ssh_opts]
      assert_equal exp, @remote_cmd_new_called_with

      assert_not_nil @remote_cmd
      assert_true @remote_cmd.run_called?
      assert_equal @cmd_input, @remote_cmd.run_input

      assert_equal exp_log_output(@remote_cmd), @log_out
    end

    private

    def exp_log_output(cmd)
      ( ["DEBUG -- #{cmd.cmd_str}\n"] +
        cmd.output_lines.map{ |ol| "DEBUG -- #{ol.line}\n" }
      ).join("")
    end

  end

  class TestTask
    include Dk::Task

    attr_reader :run_called, :run_params

    def run!
      @run_called = true
      @run_params = params
    end

  end

end
