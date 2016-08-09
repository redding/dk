require 'assert'
require 'dk/dry_runner'

require 'dk/config'
require 'dk/config_runner'
require 'dk/has_the_stubs'

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

    should "have the stubs" do
      assert_includes Dk::HasTheStubs, subject
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @dk_config = Dk::Config.new
      Factory.integer(3).times.each do
        @dk_config.stub_dry_tree_cmd(Factory.string, Factory.string, {
          Factory.string => Factory.string
        }){ |s| Factory.string }
      end
      Factory.integer(3).times.each do
        @dk_config.stub_dry_tree_ssh(Factory.string, Factory.string, {
          Factory.string => Factory.string
        }){ |s| Factory.string }
      end

      @runner = @runner_class.new(@dk_config)
    end
    subject{ @runner }

    should "add cmd/ssh dry tree stubs from its config" do
      @dk_config.dry_tree_cmd_stubs.each do |stub|
        exp = Dk::HasTheStubs::Stub.new(
          stub.cmd_str,
          stub.input,
          stub.given_opts,
          stub.block
        )
        assert_includes exp, @runner.local_cmd_stubs
      end
      @dk_config.dry_tree_ssh_stubs.each do |stub|
        exp = Dk::HasTheStubs::Stub.new(
          stub.cmd_str,
          stub.input,
          stub.given_opts,
          stub.block
        )
        assert_includes exp, @runner.remote_cmd_stubs
      end
    end

  end

end
