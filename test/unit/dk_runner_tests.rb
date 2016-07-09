require 'assert'
require 'dk/dk_runner'

require 'dk/config_runner'

class Dk::DkRunner

  class UnitTests < Assert::Context
    desc "Dk::DkRunner"
    setup do
      @runner_class = Dk::DkRunner
    end
    subject{ @runner_class }

    should "be a Dk::ConfigRunner" do
      assert_true subject < Dk::ConfigRunner
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @config = Dk::Config.new
    end

    should "be init with a config instance" do
      assert_nothing_raised{ @runner_class.new(@config) }
      assert_raises(ArgumentError){ @runner_class.new }
    end

  end

end
