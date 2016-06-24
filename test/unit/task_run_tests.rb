require 'assert'
require 'dk/task_run'

require 'dk/has_the_runs'

class Dk::TaskRun

  class UnitTests < Assert::Context
    desc "Dk::TaskRun"
    setup do
      @task_run_class = Dk::TaskRun
    end
    subject{ @task_run_class }

    should "have the runs" do
      assert_includes Dk::HasTheRuns, subject
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @task_class = Factory.string
      @params     = { Factory.string => Factory.string }

      @task_run = @task_run_class.new(@task_class, @params)
    end
    subject{ @task_run }

    should have_imeths :task_class, :params

    should "know its task class and params" do
      assert_equal @task_class, subject.task_class
      assert_equal @params,     subject.params
    end

  end

end
