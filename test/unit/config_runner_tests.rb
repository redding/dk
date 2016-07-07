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
    subject{ @runner }

    should "initialize using the config's values" do
      assert_equal @config.params,        subject.params
      assert_equal @config.ssh_hosts,     subject.ssh_hosts
      assert_equal @config.ssh_args,      subject.ssh_args
      assert_equal @config.host_ssh_args, subject.host_ssh_args
    end

  end

end
