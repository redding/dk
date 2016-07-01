require 'assert'
require 'dk/runner'

require 'dk/local'
require 'dk/null_logger'
require 'dk/task'

class Dk::Runner

  class UnitTests < Assert::Context
    desc "Dk::Runner"
    setup do
      @runner_class = Dk::Runner
    end
    subject{ @runner_class }

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
    should have_imeths :run, :run_task, :set_param
    should have_imeths :log_info, :log_debug, :log_error
    should have_imeths :cmd

    should "know its attrs" do
      assert_equal @args[:params], subject.params
      assert_equal @args[:logger], subject.logger
    end

    should "default its attrs" do
      exp = {}
      assert_equal exp, @runner_class.new.params

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

    should "build and run a given task class" do
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
    end

    should "stringify and set param values with `set_param`" do
      key, value = Factory.string.to_sym, Factory.string
      subject.set_param(key, value)

      assert_equal value, subject.params[key.to_s]
      assert_raises(ArgumentError){ subject.params[key] }
    end

    should "call to its logger for its log_* methods" do
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

  end

  class CmdTests < UnitTests
    desc "running cmds"
    setup do
      @cmd_str   = Factory.string
      @cmd_opts  = { Factory.string => Factory.string}
      @local_cmd = nil

      @local_cmd_new_called_with = nil
      Assert.stub(Dk::Local::Cmd, :new) do |*args|
        @local_cmd_new_called_with = args
        @local_cmd = Dk::Local::CmdSpy.new(*args).tap do |cmd_spy|
          cmd_spy.stdout = Factory.stdout
        end
      end

      @log_out = ""
      logger = Logger.new(StringIO.new(@log_out))
      logger.formatter = proc do |severity, datetime, progname, msg|
        "#{severity} -- #{msg}\n"
      end
      @runner  = @runner_class.new(:logger => logger)
    end
    subject{ @runner }

    should "build, log and run local cmds" do
      @runner.cmd(@cmd_str, @cmd_opts)

      exp = [@cmd_str, @cmd_opts]
      assert_equal exp, @local_cmd_new_called_with

      assert_not_nil @local_cmd
      assert_true @local_cmd.run_called?

      assert_equal exp_log_output(@local_cmd), @log_out
    end

    private

    def exp_log_output(cmd)
      ( ["INFO -- #{cmd.cmd_str}\n"] +
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
