require 'assert'
require 'dk/task'

require 'much-plugin'
require 'dk/runner'

module Dk::Task

  class UnitTests < Assert::Context
    desc "Dk::Task"
    setup do
      @task_class = Class.new{ include Dk::Task }
    end
    subject{ @task_class }

    should have_imeths :description, :desc

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

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @runner = Dk::Runner.new({
        :params => { Factory.string => Factory.string }
      })
      @task = @task_class.new(@runner)
    end
    subject{ @task }

    should have_imeths :dk_run, :run!

    should "not implement its run! method" do
      assert_raises NotImplementedError do
        subject.run!
      end
    end

    should "run other tasks by calling the runner's `run_task` method" do
      runner_run_task_called_with = nil
      Assert.stub(@runner, :run_task){ |*args| runner_run_task_called_with = args }

      other_task_class  = Class.new{ include Dk::Task }
      other_task_params = { Factory.string => Factory.string }

      subject.instance_eval{ run_task(other_task_class, other_task_params) }

      exp = [other_task_class, other_task_params]
      assert_equal exp, runner_run_task_called_with
    end

  end

  class RunTests < InitTests
    desc "and run"
    setup do
      @task_run_called = false
      Assert.stub(@task, :run!){ @task_run_called = true }
      @task.dk_run
    end

    should "call `run!`" do
      assert_true @task_run_called
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

  end

end
