require 'assert'
require 'dk/runner'

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
      @runner = @runner_class.new
    end
    subject{ @runner }

    should have_readers :params
    should have_imeths :run, :run_task, :set_param

    should "default its attrs" do
      assert_equal({}, subject.params)
    end

    should "know its attrs" do
      args = {
        :params => { Factory.string => Factory.string }
      }
      runner = @runner_class.new(args)

      assert_equal args[:params], runner.params
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
