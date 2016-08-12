require 'assert'
require 'dk/runner'

require 'stringio'
require 'dk/config'
require 'dk/dk_runner'
require 'dk/dry_runner'
require 'dk/null_logger'
require 'dk/task'
require 'dk/test_runner'
require 'dk/tree_runner'

class Dk::Runner

  class SystemTests < Assert::Context

  end

  class DryTreeRunSystemTests < SystemTests
    setup do
      @task_class = Class.new do
        include Dk::Task
        ssh_hosts Factory.string

        attr_reader :regular_cmd, :dry_tree_run_cmd, :stubbed_cmd
        attr_reader :regular_ssh, :dry_tree_run_ssh, :stubbed_ssh

        def run!
          @regular_cmd      = cmd!(params['cmd_str'])
          @dry_tree_run_cmd = cmd!(params['cmd_str'], :dry_tree_run => true)
          @stubbed_cmd      = cmd!(params['stubbed_cmd_str'], :dry_tree_run => true)
          @regular_ssh      = ssh!(params['cmd_str'])
          @dry_tree_run_ssh = ssh!(params['cmd_str'], :dry_tree_run => true)
          @stubbed_ssh      = ssh!(params['stubbed_cmd_str'], :dry_tree_run => true)
        end
      end

      # turn off the stdout logging
      @dk_config = Dk::Config.new
      @logger    = Dk::NullLogger.new
      Assert.stub(@dk_config, :dk_logger){ @logger }

      @params = {
        'cmd_str'         => Factory.string,
        'stubbed_cmd_str' => Factory.string
      }
    end
  end

  class DTRDkRunnerSystemTests < DryTreeRunSystemTests
    desc "DkRunner"
    setup do
      @runner = Dk::DkRunner.new(@dk_config)
      @task   = @runner.run(@task_class, @params)
    end
    subject{ @task }

    should "run all cmds/ssh regardless of the `dry_tree_run` opt" do
      # scmd is in test mode so we can test its spy and see if it was run
      # called; if scmd was run then as far as dk is concerned it ran the cmd
      assert_instance_of Dk::Local::Cmd, @task.regular_cmd
      assert_true @task.regular_cmd.scmd.run_called?
      assert_instance_of Dk::Local::Cmd, @task.dry_tree_run_cmd
      assert_true @task.dry_tree_run_cmd.scmd.run_called?
      assert_instance_of Dk::Local::Cmd, @task.stubbed_cmd
      assert_true @task.stubbed_cmd.scmd.run_called?

      # check that the first local cmd of the remote cmd was run
      assert_instance_of Dk::Remote::Cmd, @task.regular_ssh
      assert_true @task.regular_ssh.local_cmds.values.first.scmd.start_called?
      assert_instance_of Dk::Remote::Cmd, @task.dry_tree_run_ssh
      assert_true @task.dry_tree_run_ssh.local_cmds.values.first.scmd.start_called?
      assert_instance_of Dk::Remote::Cmd, @task.stubbed_ssh
      assert_true @task.stubbed_ssh.local_cmds.values.first.scmd.start_called?
    end

  end

  class DTRDryRunnerSystemTests < DryTreeRunSystemTests
    desc "DryRunner"
    setup do
      @runner = Dk::DryRunner.new(@dk_config)

      stub_cmd_str = [
        @params['stubbed_cmd_str'],
        proc{ params['stubbed_cmd_str']}
      ].sample

      # stub a cmd/ssh using `dry_tree_run` so we can test that the stub takes
      # precedence over the `dry_tree_run` opt
      @runner.stub_cmd(stub_cmd_str, {
        :opts => { :dry_tree_run => true }
      }) do |s|
        s.stdout = Factory.string
      end
      @runner.stub_ssh(stub_cmd_str, {
        :opts => { :dry_tree_run => true }
      }) do |s|
        s.stdout = Factory.string
      end

      @task = @runner.run(@task_class, @params)
    end
    subject{ @task }

    should "not spy cmds that use the `dry_tree_run` opt" do
      # scmd is in test mode so we can test its spy and see if it was run
      # called; if scmd was run then as far as dk is concerned it ran the cmd
      assert_instance_of Dk::Local::Cmd, @task.dry_tree_run_cmd
      assert_true @task.dry_tree_run_cmd.scmd.run_called?
      # check that the first local cmd of the remote cmd was run
      assert_instance_of Dk::Remote::Cmd, @task.dry_tree_run_ssh
      assert_true @task.dry_tree_run_ssh.local_cmds.values.first.scmd.start_called?
    end

    should "spy cmds that don't use the `dry_tree_run` opt" do
      assert_instance_of Dk::Local::CmdSpy, @task.regular_cmd
      assert_true @task.regular_cmd.run_called?
      assert_instance_of Dk::Remote::CmdSpy, @task.regular_ssh
      assert_true @task.regular_ssh.run_called?
    end

    should "spy cmds that are stubbed and use the `dry_tree_run` opt" do
      assert_instance_of Dk::Local::CmdSpy, @task.stubbed_cmd
      assert_true @task.stubbed_cmd.run_called?
      assert_instance_of Dk::Remote::CmdSpy, @task.stubbed_ssh
      assert_true @task.stubbed_ssh.run_called?
    end

  end

  class DTRTreeRunnerSystemTests < DryTreeRunSystemTests
    desc "TreeRunner"
    setup do
      @runner = Dk::TreeRunner.new(@dk_config, StringIO.new)

      stub_cmd_str = [
        @params['stubbed_cmd_str'],
        proc{ params['stubbed_cmd_str']}
      ].sample

      # stub a cmd/ssh using `dry_tree_run` so we can test that the stub takes
      # precedence over the `dry_tree_run` opt
      @runner.stub_cmd(stub_cmd_str, {
        :opts => { :dry_tree_run => true }
      }) do |s|
        s.stdout = Factory.string
      end
      @runner.stub_ssh(stub_cmd_str, {
        :opts => { :dry_tree_run => true }
      }) do |s|
        s.stdout = Factory.string
      end

      @task = @runner.run(@task_class, @params)
    end
    subject{ @task }

    should "not spy cmds that use the `dry_tree_run` opt" do
      # scmd is in test mode so we can test its spy and see if it was run
      # called; if scmd was run then as far as dk is concerned it ran the cmd
      assert_instance_of Dk::Local::Cmd, @task.dry_tree_run_cmd
      assert_true @task.dry_tree_run_cmd.scmd.run_called?
      # check that the first local cmd of the remote cmd was run
      assert_instance_of Dk::Remote::Cmd, @task.dry_tree_run_ssh
      assert_true @task.dry_tree_run_ssh.local_cmds.values.first.scmd.start_called?
    end

    should "spy cmds that don't use the `dry_tree_run` opt" do
      assert_instance_of Dk::Local::CmdSpy, @task.regular_cmd
      assert_true @task.regular_cmd.run_called?
      assert_instance_of Dk::Remote::CmdSpy, @task.regular_ssh
      assert_true @task.regular_ssh.run_called?
    end

    should "spy cmds that are stubbed and use the `dry_tree_run` opt" do
      assert_instance_of Dk::Local::CmdSpy, @task.stubbed_cmd
      assert_true @task.stubbed_cmd.run_called?
      assert_instance_of Dk::Remote::CmdSpy, @task.stubbed_ssh
      assert_true @task.stubbed_ssh.run_called?
    end

  end

  class DTRTestRunnerSystemTests < DryTreeRunSystemTests
    desc "TestRunner"
    setup do
      @runner = Dk::TestRunner.new(:logger => @logger)
      @runner.task_class = @task_class

      # stub a cmd/ssh using `dry_tree_run` so we can test that the stub takes
      # precedence over the `dry_tree_run` opt
      @runner.stub_cmd(@params['stubbed_cmd_str'], :dry_tree_run => true) do |s|
        s.stdout = Factory.string
      end
      @runner.stub_ssh(@params['stubbed_cmd_str'], :dry_tree_run => true) do |s|
        s.stdout = Factory.string
      end

      @task = @runner.run(@params)
    end
    subject{ @task }

    should "spy all cmds/ssh regardless of the `dry_tree_run` opt" do
      assert_instance_of Dk::Local::CmdSpy, @task.dry_tree_run_cmd
      assert_true @task.dry_tree_run_cmd.run_called?
      assert_instance_of Dk::Local::CmdSpy, @task.regular_cmd
      assert_true @task.regular_cmd.run_called?
      assert_instance_of Dk::Local::CmdSpy, @task.stubbed_cmd
      assert_true @task.stubbed_cmd.run_called?

      assert_instance_of Dk::Remote::CmdSpy, @task.dry_tree_run_ssh
      assert_true @task.dry_tree_run_cmd.run_called?
      assert_instance_of Dk::Remote::CmdSpy, @task.regular_ssh
      assert_true @task.regular_ssh.run_called?
      assert_instance_of Dk::Remote::CmdSpy, @task.stubbed_ssh
      assert_true @task.stubbed_ssh.run_called?
    end

  end

end
