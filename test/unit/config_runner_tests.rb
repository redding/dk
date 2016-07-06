require 'assert'
require 'dk/config_runner'

require 'dk/config'
require 'dk/runner'

class Dk::ConfigRunner

  class UnitTests < Assert::Context
    desc "Dk::ConfigRunner"
    setup do
      @runner_class = Dk::ConfigRunner
    end
    subject{ @runner_class }

    should "be a Dk::Runner" do
      assert_true subject < Dk::Runner
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @config = Dk::Config.new
      @runner = @runner_class.new(@config)
    end

    # TODO: test that the runner gets set with config values

  end

end
