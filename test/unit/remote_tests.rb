require 'assert'
require 'dk/remote'

require 'dk/local'

module Dk::Remote

  class UnitTests < Assert::Context
    desc "Dk::Remote"
    setup do
      @hosts   = Factory.integer(3).times.map{ Factory.string }
      @cmd_str = Factory.string

      @opts = {
        :env           => Factory.string,
        :hosts         => @hosts,
        Factory.string => Factory.string
      }

      @local_cmd_new_called_with = nil
      Assert.stub(Dk::Local::Cmd, :new) do |*args|
        @local_cmd_new_called_with = args
        Assert.stub_send(Dk::Local::Cmd, :new, *args)
      end

      @local_cmd_spy_new_called_with = nil
      Assert.stub(Dk::Local::CmdSpy, :new) do |*args|
        @local_cmd_spy_new_called_with = args
        Assert.stub_send(Dk::Local::CmdSpy, :new, *args).tap do |spy|
          spy.exitstatus = Factory.exitstatus
          spy.stdout     = [Factory.stdout, nil].sample
          spy.stderr     = [Factory.stderr, nil].sample
        end
      end
    end
    subject{ @cmd }

  end

  class BaseCmdTests < UnitTests
    desc "BaseCmd"
    setup do
      @cmd_class = Dk::Remote::BaseCmd
      @cmd = @cmd_class.new(Dk::Local::CmdSpy, @cmd_str, @opts)
    end

    should have_readers :hosts, :cmd_str, :local_cmds
    should have_imeths :to_s, :run, :success?, :output_lines

    should "know its hosts" do
      assert_equal @hosts.sort, subject.hosts
    end

    should "know its cmd str" do
      assert_equal @cmd_str,        subject.cmd_str
      assert_equal subject.cmd_str, subject.to_s
    end

    should "build a local cmd for each of its hosts" do
      subject.hosts.each do |host|
        assert_instance_of Dk::Local::CmdSpy, subject.local_cmds[host]
        assert_equal @cmd_str, subject.local_cmds[host].cmd_str
      end
      assert_equal [@cmd_str, { :env => @opts[:env] }], @local_cmd_spy_new_called_with

      cmd = @cmd_class.new(Dk::Local::Cmd, @cmd_str, @opts)
      cmd.hosts.each do |host|
        assert_instance_of Dk::Local::Cmd, cmd.local_cmds[host]
        assert_equal @cmd_str, cmd.local_cmds[host].cmd_str
      end
      assert_equal [@cmd_str, { :env => @opts[:env] }], @local_cmd_new_called_with
    end

    should "start and wait on each of its local cmds' scmd when run" do
      subject.hosts.each do |host|
        assert_false subject.local_cmds[host].scmd.start_called?
        assert_false subject.local_cmds[host].scmd.wait_called?
      end

      input = Factory.string
      subject.run(input)

      subject.hosts.each do |host|
        assert_true subject.local_cmds[host].scmd.start_called?
        assert_true subject.local_cmds[host].scmd.wait_called?
        assert_equal input, subject.local_cmds[host].scmd.start_calls.last.input
      end
    end

    should "know whether it was successful or not" do
      subject.hosts.each do |host|
        Assert.stub(subject.local_cmds[host], :success?){ true }
      end
      assert_true subject.success?

      Assert.stub(subject.local_cmds[subject.hosts.sample], :success?){ false }
      assert_false subject.success?
    end

    should "know its output lines" do
      exp = []
      subject.hosts.each do |host|
        exp += subject.local_cmds[host].output_lines
      end
      assert_equal exp, subject.output_lines
    end

  end

  class CmdTests < UnitTests
    desc "Cmd"
    setup do
      @cmd_class = Dk::Remote::Cmd
      @cmd = @cmd_class.new(@cmd_str, :hosts => @hosts)
    end

    should "build a local cmd for each host with the cmd str, given opts" do
      subject.hosts.each do |host|
        assert_instance_of Dk::Local::Cmd, subject.local_cmds[host]
        assert_equal @cmd_str, subject.local_cmds[host].cmd_str
      end
      assert_equal [@cmd_str, { :env => nil }], @local_cmd_new_called_with

      cmd  = @cmd_class.new(@cmd_str, @opts)
      cmd.hosts.each do |host|
        assert_instance_of Dk::Local::Cmd, cmd.local_cmds[host]
        assert_equal @cmd_str, cmd.local_cmds[host].cmd_str
      end
      assert_equal [@cmd_str, { :env => @opts[:env] }], @local_cmd_new_called_with
    end

  end

  class CmdSpyTests < UnitTests
    desc "CmdSpy"
    setup do
      @cmd_class = Dk::Remote::CmdSpy
      @cmd = @cmd_class.new(@cmd_str, :hosts => @hosts)
    end

    should have_readers :cmd_opts
    should have_imeths :exitstatus=, :run_calls, :run_called?

    should "build a local cmd spy for each host with the cmd str, given opts" do
      subject.hosts.each do |host|
        assert_instance_of Dk::Local::CmdSpy, subject.local_cmds[host]
        assert_equal @cmd_str, subject.local_cmds[host].cmd_str
      end
      assert_equal [@cmd_str, { :env => nil }], @local_cmd_spy_new_called_with

      cmd  = @cmd_class.new(@cmd_str, @opts)
      cmd.hosts.each do |host|
        assert_instance_of Dk::Local::CmdSpy, cmd.local_cmds[host]
        assert_equal @cmd_str, cmd.local_cmds[host].cmd_str
      end
      assert_equal [@cmd_str, { :env => @opts[:env] }], @local_cmd_spy_new_called_with
    end

    should "demeter its first local cmd spy" do
      first_local_cmd_spy = subject.local_cmds[subject.hosts.first]

      exitstatus = Factory.exitstatus
      subject.exitstatus = exitstatus
      assert_equal exitstatus, first_local_cmd_spy.scmd.exitstatus

      subject.run
      assert_equal first_local_cmd_spy.scmd.start_calls,   subject.run_calls
      assert_equal first_local_cmd_spy.scmd.start_called?, subject.run_called?
    end

  end

end
