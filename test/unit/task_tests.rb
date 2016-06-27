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
    should have_imeths :before_callbacks, :after_callbacks
    should have_imeths :before, :after, :prepend_before, :prepend_after

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

    should "know its default callbacks" do
      assert_equal [], subject.before_callbacks
      assert_equal [], subject.after_callbacks
    end

    should "append callbacks" do
      task_class = Factory.string
      params     = Factory.string

      subject.before_callbacks << Factory.string
      subject.before(task_class, params)
      assert_equal task_class, subject.before_callbacks.last.task_class
      assert_equal params,     subject.before_callbacks.last.params

      subject.after_callbacks << Factory.string
      subject.after(task_class, params)
      assert_equal task_class, subject.after_callbacks.last.task_class
      assert_equal params,     subject.after_callbacks.last.params
    end

    should "prepend callbacks" do
      task_class = Factory.string
      params     = Factory.string

      subject.before_callbacks << Factory.string
      subject.prepend_before(task_class, params)
      assert_equal task_class, subject.before_callbacks.first.task_class
      assert_equal params,     subject.before_callbacks.first.params

      subject.after_callbacks << Factory.string
      subject.prepend_after(task_class, params)
      assert_equal task_class, subject.after_callbacks.first.task_class
      assert_equal params,     subject.after_callbacks.first.params
    end

  end

  class InitTests < UnitTests
    include Dk::Task::TestHelpers

    desc "when init"
    setup do
      @runner = test_runner(@task_class, {
        :params => { Factory.string => Factory.string }
      })
      @task = @runner.task
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

    should "know if it is equal to another task" do
      task = @task_class.new(@runner)
      assert_equal task, subject

      task = Class.new{ include Dk::Task }.new(@runner)
      assert_not_equal task, subject
    end

  end

  class RunTests < InitTests
    desc "and run"
    setup do
      # build a call orders object to pass around to the callback tasks for
      # shared state call order
      @call_orders = CallOrders.new

      # build a base runner and task manually so the callback tasks actually
      # run (b/c the test runner doesn't run callbacks)
      @runner = Dk::Runner.new({
        :params => { 'call_orders' => @call_orders }
      })

      # use this TestTask that has a bunch of callbacks configured so we can
      # test callback run and call order.  Also this TestTask uses callback
      # params which will test all the params handling in callbacks and the
      # task running behavior.
      @task = TestTask.new(@runner)

      @task.dk_run
    end

    should "call `run!` and run any callback tasks" do
      assert_equal 1,  @call_orders.prepend_before_call_order
      assert_equal 2,  @call_orders.first_before_call_order
      assert_equal 3,  @call_orders.second_before_call_order
      assert_equal 4,  @call_orders.run_call_order
      assert_equal 5,  @call_orders.prepend_after_call_order
      assert_equal 6,  @call_orders.first_after_call_order
      assert_equal 7,  @call_orders.second_after_call_order
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

  class TestHelpersTests < UnitTests
    desc "TestHelpers"
    setup do
      @args = {
        :params => { Factory.string => Factory.string }
      }

      context_class = Class.new{ include Dk::Task::TestHelpers }
      @context = context_class.new
    end
    subject{ @context }

    should have_imeths :test_runner, :test_task

    should "build a test runner for a given handler class" do
      runner = subject.test_runner(@task_class, @args)

      assert_kind_of Dk::TestRunner, runner
      assert_equal @task_class,      runner.task_class
      assert_equal @args[:params],   runner.params
    end

    should "return an initialized task instance" do
      task = subject.test_task(@task_class, @args)
      assert_kind_of @task_class, task

      exp = subject.test_runner(@task_class, @args).task
      assert_equal exp, task
    end

  end

  class CallOrders
    attr_reader :first_before_call_order, :second_before_call_order
    attr_reader :prepend_before_call_order
    attr_reader :first_after_call_order, :second_after_call_order
    attr_reader :prepend_after_call_order
    attr_reader :run_call_order

    def first_before;   @first_before_call_order   = next_call_order; end
    def second_before;  @second_before_call_order  = next_call_order; end
    def prepend_before; @prepend_before_call_order = next_call_order; end
    def first_after;    @first_after_call_order    = next_call_order; end
    def second_after;   @second_after_call_order   = next_call_order; end
    def prepend_after;  @prepend_after_call_order  = next_call_order; end

    def run; @run_call_order = next_call_order; end

    private

    def next_call_order
      @order ||= 0
      @order += 1
    end
  end

  class CallbackTask
    include Dk::Task

    def run!
      params['call_orders'].send(params['callback'])
    end
  end

  class TestTask
    include Dk::Task

    attr_reader :first_before_call_order, :second_before_call_order
    attr_reader :first_after_call_order, :second_after_call_order
    attr_reader :run_call_order

    before         CallbackTask, 'callback' => 'first_before'
    before         CallbackTask, 'callback' => 'second_before'
    prepend_before CallbackTask, 'callback' => 'prepend_before'

    after         CallbackTask, 'callback' => 'first_after'
    after         CallbackTask, 'callback' => 'second_after'
    prepend_after CallbackTask, 'callback' => 'prepend_after'

    def run!
      params['call_orders'].run
    end
  end

end
