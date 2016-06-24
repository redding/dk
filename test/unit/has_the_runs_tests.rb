require 'assert'
require 'dk/has_the_runs'

require 'much-plugin'

module Dk::HasTheRuns

  class UnitTests < Assert::Context
    desc "Dk::HasTheRuns"
    setup do
      @mixin_class = Dk::HasTheRuns
      @runs_class  = Class.new{ include Dk::HasTheRuns }
    end
    subject{ @mixin_class }

    should "use much-plugin" do
      assert_includes MuchPlugin, subject
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @runs = @runs_class.new
    end
    subject{ @runs }

    should have_imeths :runs

    should "have no runs by default" do
      assert_equal [], subject.runs
    end

  end

end
