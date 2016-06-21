require 'assert'
require 'dk/task'

require 'much-plugin'

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
      @task = @task_class.new
    end
    subject{ @task }

    should have_imeths :dk_run, :run!

    should "not implement its run! method" do
      assert_raises NotImplementedError do
        subject.run!
      end
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

end
