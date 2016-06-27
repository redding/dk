require 'assert'
require 'dk/null_logger'

class Dk::NullLogger

  class UnitTests < Assert::Context
    desc "Dk::NullLogger"
    setup do
      @null_logger = Dk::NullLogger.new
    end
    subject{ @null_logger }

    should have_imeths :info, :debug, :error

  end

end
