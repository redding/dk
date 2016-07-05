require 'assert'
require 'dk/dry_runner'

require 'dk/config_runner'

class Dk::DryRunner

  class UnitTests < Assert::Context
    desc "Dk::DryRunner"
    setup do
      @runner_class = Dk::DryRunner
    end
    subject{ @runner_class }

    should "be a Dk::ConfigRunner" do
      assert_true subject < Dk::ConfigRunner
    end

  end

end
