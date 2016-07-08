require 'assert'
require 'dk/tree_runner'

require 'dk/config'
require 'dk/dry_runner'
require 'dk/has_the_runs'
require 'dk/null_logger'
require 'dk/task'
require 'dk/task_run'

class Dk::TreeRunner

  class UnitTests < Assert::Context
    desc "Dk::TreeRunner"
    setup do
      @runner_class = Dk::TreeRunner
    end
    subject{ @runner_class }

    should "be a Dk::DryRunner" do
      assert_true subject < Dk::DryRunner
    end

    should "have the runs" do
      assert_includes Dk::HasTheRuns, subject
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      config = Dk::Config.new
      @runner = @runner_class.new(config)
    end
    subject{ @runner }

    should "force a null logger to disable logging" do
      assert_instance_of Dk::NullLogger, subject.logger
    end

  end

  class RunTests < InitTests
    desc "and run"
    setup do
      @params = { Factory.string => Factory.string }
      @task = @runner.run(TestTask, @params)
    end
    subject{ @task }

    should "run the task with any given params and run any sub-tasks" do
      assert_true subject.run_called
      assert_equal @params, subject.run_params

      sub_task = subject.sub_task
      assert_instance_of TestTask::SubTask, sub_task
      assert_true sub_task.run_called
      assert_equal subject.sub_task_params, sub_task.run_params

      sub_sub_task = sub_task.sub_task
      assert_instance_of TestTask::SubSubTask, sub_sub_task
      assert_true sub_sub_task.run_called
      assert_equal sub_task.sub_task_params, sub_sub_task.run_params
    end

    should "capture any sub-tasks that were run" do
      assert_equal 1, @runner.runs.size

      task_run = @runner.runs.first
      assert_equal TestTask, task_run.task_class
      assert_equal @params,  task_run.params

      assert_equal 1, task_run.runs.size

      sub_task_run = task_run.runs.first
      assert_equal TestTask::SubTask,       sub_task_run.task_class
      assert_equal subject.sub_task_params, sub_task_run.params

      assert_equal 1, sub_task_run.runs.size

      sub_sub_task_run = sub_task_run.runs.first
      assert_equal TestTask::SubSubTask,             sub_sub_task_run.task_class
      assert_equal subject.sub_task.sub_task_params, sub_sub_task_run.params
    end

  end

  class TestTask
    include Dk::Task

    attr_reader :run_called, :run_params
    attr_reader :sub_task_params, :sub_task

    def run!
      @run_called = true
      @run_params = params

      @sub_task_params = { Factory.string => Factory.string }
      @sub_task = run_task(SubTask, @sub_task_params)
    end

    class SubTask
      include Dk::Task

      attr_reader :run_called, :run_params
      attr_reader :sub_task_params, :sub_task

      def run!
        @run_called = true
        @run_params = params

        @sub_task_params = { Factory.string => Factory.string }
        @sub_task = run_task(SubSubTask, @sub_task_params)
      end
    end

    class SubSubTask
      include Dk::Task

      attr_reader :run_called, :run_params

      def run!
        @run_called = true
        @run_params = params
      end
    end

  end

end
