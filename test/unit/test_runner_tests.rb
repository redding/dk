require 'assert'
require 'dk/test_runner'

require 'dk/has_the_runs'
require 'dk/runner'
require 'dk/task'
require 'dk/task_run'

class Dk::TestRunner

  class UnitTests < Assert::Context
    desc "Dk::TestRunner"
    setup do
      @runner_class = Dk::TestRunner
    end
    subject{ @runner_class }

    should "be a Dk::Runner" do
      assert_true subject < Dk::Runner
    end

    should "have the runs" do
      assert_includes Dk::HasTheRuns, subject
    end

    should "know its Scmd test mode value" do
      assert_equal 'yes', subject::SCMD_TEST_MODE_VALUE
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @runner = @runner_class.new
      @runner.task_class = TestTask
    end
    subject{ @runner }

    should have_accessors :task_class
    should have_imeths :task
    should have_imeths :stub_cmd, :unstub_cmd, :unstub_all_cmds
    should have_imeths :stub_ssh, :unstub_ssh, :unstub_all_ssh

    should "know how to build a task of its task class" do
      params = { Factory.string => Factory.string }
      task = subject.task(params)

      assert_instance_of subject.task_class, task
      assert_equal params, task.instance_eval{ params }
    end

  end

  class RunTests < InitTests
    desc "and run"
    setup do
      @params = { Factory.string => Factory.string }
      @orig_scmd_test_mode = ENV['SCMD_TEST_MODE']
      ENV['SCMD_TEST_MODE'] = Factory.string
      @task = @runner.run(@params)
    end
    teardown do
      ENV['SCMD_TEST_MODE'] = @orig_scmd_test_mode
    end
    subject{ @task }

    should "run the task with any given params" do
      assert_true subject.run_called
      assert_equal @params, subject.run_params
    end

    should "capture any sub-tasks or local/remote cmd spies that were run" do
      assert_equal 5, @runner.runs.size

      st, lc, lcb, rc, rcb = @runner.runs

      assert_instance_of Dk::TaskRun,        st
      assert_instance_of Dk::Local::CmdSpy,  lc
      assert_instance_of Dk::Local::CmdSpy,  lcb
      assert_instance_of Dk::Remote::CmdSpy, rc
      assert_instance_of Dk::Remote::CmdSpy, rcb

      assert_same st, subject.sub_task
      assert_equal TestTask::SubTask,       st.task_class
      assert_equal subject.sub_task_params, st.params
      assert_equal [],                      st.runs

      assert_same lc, subject.local_cmd
      assert_equal subject.local_cmd_str,   lc.cmd_str
      assert_equal subject.local_cmd_opts,  lc.cmd_opts
      assert_equal subject.local_cmd_input, lc.run_input
      assert_true lc.run_called?

      assert_same lcb, subject.local_cmd_bang
      assert_equal subject.local_cmd_str,   lcb.cmd_str
      assert_equal subject.local_cmd_opts,  lcb.cmd_opts
      assert_equal subject.local_cmd_input, lcb.run_input
      assert_true lcb.run_called?

      assert_same rc, subject.remote_cmd
      assert_equal subject.remote_cmd_str,   rc.cmd_str
      assert_equal subject.remote_cmd_opts,  rc.cmd_opts
      assert_equal subject.remote_cmd_input, rc.run_input
      assert_true rc.run_called?

      assert_same rcb, subject.remote_cmd_bang
      assert_equal subject.remote_cmd_str,   rcb.cmd_str
      assert_equal subject.remote_cmd_opts,  rcb.cmd_opts
      assert_equal subject.remote_cmd_input, rcb.run_input
      assert_true rcb.run_called?
    end

    should "put Scmd in test mode while running" do
      exp = @runner_class::SCMD_TEST_MODE_VALUE
      assert_equal     exp, subject.scmd_test_mode_run_value
      assert_not_equal exp, ENV['SCMD_TEST_MODE']
    end

  end

  class CmdStubTests < InitTests
    setup do
      @task = @runner.task

      cmd_spy = nil
      stdout  = Factory.stdout
      @runner.stub_cmd(@task.local_cmd_str, @task.local_cmd_opts) do |spy|
        spy.stdout = stdout
        cmd_spy    = spy
      end

      @cmd_spy = cmd_spy
      @stdout  = stdout
    end
    subject{ @task }

    should "stub custom cmd spies" do
      @runner.run

      assert_same @cmd_spy, subject.local_cmd
      assert_same @cmd_spy, subject.local_cmd_bang

      assert_true @cmd_spy.run_called?

      assert_equal @stdout, subject.local_cmd.stdout
      assert_equal @stdout, subject.local_cmd_bang.stdout
    end

    should "unstub specific cmd spies" do
      @runner.unstub_cmd(@task.local_cmd_str, @task.local_cmd_opts)

      @runner.run

      assert_not_same @cmd_spy, subject.local_cmd
      assert_not_same @cmd_spy, subject.local_cmd_bang
    end

    should "unstub all cmd spies" do
      @runner.unstub_all_cmds

      @runner.run

      assert_not_same @cmd_spy, subject.local_cmd
      assert_not_same @cmd_spy, subject.local_cmd_bang
    end

  end

  class SSHStubTests < InitTests
    setup do
      @task = @runner.task

      cmd_spy = nil
      @runner.stub_ssh(@task.remote_cmd_str, @task.remote_cmd_opts) do |spy|
        cmd_spy = spy
      end
      @cmd_spy = cmd_spy
    end
    subject{ @task }

    should "stub custom ssh cmd spies" do
      @runner.run

      assert_same @cmd_spy, subject.remote_cmd
      assert_same @cmd_spy, subject.remote_cmd_bang

      assert_true @cmd_spy.run_called?
    end

    should "unstub specific ssh cmd spies" do
      @runner.unstub_ssh(@task.remote_cmd_str, @task.remote_cmd_opts)

      @runner.run

      assert_not_same @cmd_spy, subject.remote_cmd
      assert_not_same @cmd_spy, subject.remote_cmd_bang
    end

    should "unstub all ssh cmd spies" do
      @runner.unstub_all_ssh

      @runner.run

      assert_not_same @cmd_spy, subject.remote_cmd
      assert_not_same @cmd_spy, subject.remote_cmd_bang
    end

  end

  class TestTask
    include Dk::Task

    attr_reader :run_called, :run_params
    attr_reader :sub_task
    attr_reader :local_cmd, :local_cmd_bang
    attr_reader :remote_cmd, :remote_cmd_bang
    attr_reader :scmd_test_mode_run_value

    def sub_task_params
      @sub_task_params ||= { Factory.string => Factory.string }
    end

    def local_cmd_str
      @local_cmd_str ||= Factory.string
    end

    def local_cmd_input
      @local_cmd_input ||= Factory.string
    end

    def local_cmd_opts
      @local_cmd_opts ||= { Factory.string => Factory.string }
    end

    def remote_cmd_str
      @remote_cmd_str ||= Factory.string
    end

    def remote_cmd_input
      @remote_cmd_input ||= Factory.string
    end

    def remote_cmd_opts
      @remote_cmd_opts ||= {
        Factory.string => Factory.string,
        :hosts         => Factory.hosts,
        :ssh_args      => Factory.string,
        :host_ssh_args => { Factory.string => Factory.string }
      }
    end

    def run!
      @run_called = true
      @run_params = params

      @sub_task        = run_task(SubTask, self.sub_task_params)
      @local_cmd       = cmd(self.local_cmd_str, self.local_cmd_input, self.local_cmd_opts)
      @local_cmd_bang  = cmd!(self.local_cmd_str, self.local_cmd_input, self.local_cmd_opts)
      @remote_cmd      = ssh(self.remote_cmd_str, self.remote_cmd_input, self.remote_cmd_opts)
      @remote_cmd_bang = ssh!(self.remote_cmd_str, self.remote_cmd_input, self.remote_cmd_opts)

      @scmd_test_mode_run_value = ENV['SCMD_TEST_MODE']
    end

    class SubTask
      include Dk::Task

      attr_reader :run_called, :run_params

      def run!
        @run_called = true
        @run_params = params
        run_task(SubSubTask)
      end
    end

    class SubSubTask
      include Dk::Task

      def run!
        # no-op
      end
    end

  end

end
