require 'assert'
require 'dk/runner'

require 'dk'
require 'dk/ansi'
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

    should "know its log prefix values" do
      assert_equal ' >>>  ', subject::TASK_START_LOG_PREFIX
      assert_equal ' <<<  ', subject::TASK_END_LOG_PREFIX
      assert_equal '      ', subject::INDENT_LOG_PREFIX
      assert_equal '[CMD] ', subject::CMD_LOG_PREFIX
      assert_equal '[SSH] ', subject::SSH_LOG_PREFIX
      assert_equal "> ",     subject::CMD_SSH_OUT_LOG_PREFIX
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
    should have_imeths :log_info, :log_debug, :log_error
    should have_imeths :log_task_run, :log_cli_run
    should have_imeths :start, :cmd, :ssh
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
      assert_raises(Dk::NoParamError){ subject.params[key] }

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

      msg    = Factory.string
      styles = [[], [:bold, :red]].sample

      subject.log_info msg, *styles
      exp = ["#{INDENT_LOG_PREFIX}#{Dk::Ansi.styled_msg(msg, *styles)}"]
      assert_equal exp, logger_info_called_with

      subject.log_debug msg, *styles
      exp = ["#{INDENT_LOG_PREFIX}#{Dk::Ansi.styled_msg(msg, *styles)}"]
      assert_equal exp, logger_debug_called_with

      subject.log_error msg, *styles
      exp = ["#{INDENT_LOG_PREFIX}#{Dk::Ansi.styled_msg(msg, *styles)}"]
      assert_equal exp, logger_error_called_with
    end

    should "debug log the start/finish of task runs, including their run time" do
      logger_debug_calls = []
      Assert.stub(@args[:logger], :debug){ |*args| logger_debug_calls << args }

      pretty_run_time = Factory.string
      Assert.stub(subject, :pretty_run_time){ pretty_run_time }

      task_class = Class.new{ include Dk::Task; def run!; end }
      subject.log_task_run(task_class){}

      exp = [
        ["#{TASK_START_LOG_PREFIX}#{task_class}"],
        ["#{TASK_END_LOG_PREFIX}#{task_class} (#{pretty_run_time})"],
      ]
      assert_equal exp, logger_debug_calls
    end

    should "log the start/finish of CLI task runs, including their run time" do
      logger_info_calls = []
      Assert.stub(@args[:logger], :info){ |*args| logger_info_calls << args }

      pretty_run_time = Factory.string
      Assert.stub(subject, :pretty_run_time){ pretty_run_time }

      task_name = Factory.string
      subject.log_cli_task_run(task_name){}

      exp = [
        ["Starting `#{task_name}`."],
        ["`#{task_name}` finished in #{pretty_run_time}."],
        [""],
        [""]
      ]
      assert_equal exp, logger_info_calls
    end

    should "log the start of CLI runs" do
      logger_calls = []
      Assert.stub(@args[:logger], :debug){ |*args| logger_calls << [:debug, *args] }
      Assert.stub(@args[:logger], :info){ |*args| logger_calls << [:info, *args] }

      pretty_run_time = Factory.string
      Assert.stub(subject, :pretty_run_time){ pretty_run_time }

      cli_argv = Factory.string
      subject.log_cli_run(cli_argv){}

      exp = 15.times.map{ [:debug, ""] } + [
        [:debug, "===================================="],
        [:debug, ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> `#{cli_argv}`"],
        [:debug, "===================================="],
        [:info,  "(#{pretty_run_time})"],
        [:debug, "===================================="],
        [:debug, "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< `#{cli_argv}`"],
        [:debug, "===================================="]
      ]
      assert_equal exp, logger_calls
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
      run_time = Factory.float(1.5)
      exp = "#{(run_time * 10_000).round / 10.0}ms"
      assert_equal exp, subject.pretty_run_time(run_time)

      run_time = Factory.float(0.1) + 1.5
      exp = "#{run_time.to_i / 60}:#{(run_time.round % 60).to_i.to_s.rjust(2, '0')}s"
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

      @task   = Factory.string
      @runner = @runner_class.new(@runner_opts)

      @pretty_run_time = Factory.string
      Assert.stub(subject, :pretty_run_time){ @pretty_run_time }
    end

    should "build, log, and start local cmds" do
      @runner.start(@task, @cmd_str, @cmd_input, @cmd_given_opts)

      exp = [@cmd_str, @cmd_given_opts]
      assert_equal exp, @local_cmd_new_called_with

      assert_not_nil @local_cmd
      assert_true @local_cmd.start_called?
      assert_equal @cmd_input, @local_cmd.start_input

      assert_equal exp_log_output(@local_cmd), @log_out
    end

    should "build, log, and run local cmds" do
      @runner.cmd(@task, @cmd_str, @cmd_input, @cmd_given_opts)

      exp = [@cmd_str, @cmd_given_opts]
      assert_equal exp, @local_cmd_new_called_with

      assert_not_nil @local_cmd
      assert_true @local_cmd.run_called?
      assert_equal @cmd_input, @local_cmd.run_input

      assert_equal exp_log_output(@local_cmd), @log_out
    end

    private

    def exp_log_output(cmd)
      ( ["INFO -- #{CMD_LOG_PREFIX}#{cmd.cmd_str}\n"] +
        ["INFO -- #{INDENT_LOG_PREFIX}(#{@pretty_run_time})\n"] +
        cmd.output_lines.map do |ol|
          "DEBUG -- #{INDENT_LOG_PREFIX}#{CMD_SSH_OUT_LOG_PREFIX}#{ol.line}\n"
        end
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

      @task   = Factory.string
      @runner = @runner_class.new(@runner_opts)

      @pretty_run_time = Factory.string
      Assert.stub(subject, :pretty_run_time){ @pretty_run_time }
    end

    should "build, log and run remote cmds" do
      @runner.ssh(@task, @cmd_str, @cmd_input, @cmd_given_opts, @cmd_ssh_opts)

      exp = [@cmd_str, @cmd_ssh_opts]
      assert_equal exp, @remote_cmd_new_called_with

      assert_not_nil @remote_cmd
      assert_true @remote_cmd.run_called?
      assert_equal @cmd_input, @remote_cmd.run_input

      assert_equal exp_log_output(@remote_cmd), @log_out
    end

    private

    def exp_log_output(cmd)
      ( ["INFO -- #{SSH_LOG_PREFIX}#{cmd.cmd_str}\n"] +
        ["DEBUG -- #{INDENT_LOG_PREFIX}#{cmd.ssh_cmd_str('<host>')}\n"] +
        cmd.hosts.map{ |h| "INFO -- #{INDENT_LOG_PREFIX}[#{h}]\n" } +
        ["INFO -- #{INDENT_LOG_PREFIX}(#{@pretty_run_time})\n"] +
        cmd.output_lines.map do |ol|
          "DEBUG -- #{INDENT_LOG_PREFIX}[#{ol.host}] #{CMD_SSH_OUT_LOG_PREFIX}#{ol.line}\n"
        end
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
