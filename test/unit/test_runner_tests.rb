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
      @task = @runner.run(@params)
    end
    subject{ @task }

    should "run the task with any given params" do
      assert_true subject.run_called
      assert_equal @params, subject.run_params
    end

    should "capture any sub-tasks that were run but not actually run them" do
      assert_equal 1, @runner.runs.size

      sub_task_run = @runner.runs.first
      assert_equal TestTask::SubTask,       sub_task_run.task_class
      assert_equal subject.sub_task_params, sub_task_run.params
      assert_equal [],                      sub_task_run.runs
    end

  end

  class TestTask
    include Dk::Task

    attr_reader :run_called, :run_params
    attr_reader :sub_task_params

    def run!
      @run_called = true
      @run_params = params

      @sub_task_params = { Factory.string => Factory.string }
      run_task(SubTask, @sub_task_params)
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
