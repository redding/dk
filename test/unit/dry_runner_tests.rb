require 'assert'
require 'dk/dry_runner'

require 'dk/runner'

class Dk::DryRunner

  class UnitTests < Assert::Context
    desc "Dk::DryRunner"
    setup do
      @runner_class = Dk::DryRunner
    end
    subject{ @runner_class }

    should "be a Dk::Runner" do
      assert_true subject < Dk::Runner
    end

  end

end
