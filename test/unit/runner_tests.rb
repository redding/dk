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
    should have_imeths :run

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

    should "not implement its run method" do
      assert_raises(NotImplementedError){ subject.run(TestTask) }
    end

  end

  TestTask = Class.new{ include Dk::Task }

end
