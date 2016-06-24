require 'assert'
require 'dk/dk_runner'

require 'dk/runner'

class Dk::DkRunner

  class UnitTests < Assert::Context
    desc "Dk::DkRunner"
    setup do
      @runner_class = Dk::DkRunner
    end
    subject{ @runner_class }

    should "be a Dk::Runner" do
      assert_true subject < Dk::Runner
    end

  end

end
