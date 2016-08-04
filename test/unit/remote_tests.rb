require 'assert'
require 'dk/remote'

require 'dk/local'

module Dk::Remote

  class UnitTests < Assert::Context
    desc "Dk::Remote"
    setup do
      @hosts         = Factory.hosts
      @ssh_args      = Factory.string
      @host_ssh_args = { @hosts.sample => Factory.string }
      @cmd_str       = Factory.string

      @opts = {
        :env           => { Factory.string => Factory.string },
        :dry_tree_run  => Factory.boolean,
        :hosts         => @hosts,
        :ssh_args      => @ssh_args,
        :host_ssh_args => @host_ssh_args,
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

      @remote_class = Dk::Remote
    end
    subject{ @remote_class }

    should have_imeths :ssh_cmd_str

    should "build ssh cmd strs" do
      h = @host_ssh_args.keys.first
      exp = ssh_cmd_str(@cmd_str, h, @ssh_args, @host_ssh_args)
      assert_equal exp, subject.ssh_cmd_str(@cmd_str, h, @ssh_args, @host_ssh_args)
    end

    private

    def ssh_cmd_str(cmd_str, host, args, host_args)
      val = "\"#{cmd_str}\"".gsub("\\", "\\\\\\").gsub('"', '\"')
      "ssh #{args} #{host_args[host]} #{host} -- \"sh -c #{val}\""
    end

  end

  class BaseCmdTests < UnitTests
    desc "BaseCmd"
    setup do
      @cmd_class = @remote_class::BaseCmd
      @cmd = @cmd_class.new(Dk::Local::CmdSpy, @cmd_str, @opts)
    end
    subject{ @cmd }

    should have_readers :hosts, :ssh_args, :host_ssh_args, :cmd_str, :local_cmds
    should have_imeths :to_s, :run, :success?, :output_lines

    should "know its hosts" do
      assert_equal @hosts.sort, subject.hosts
    end

    should "complain if not given any hosts" do
      assert_raises(NoHostsError) do
        @cmd_class.new(Dk::Local::CmdSpy, @cmd_str, :hosts => nil)
      end
      assert_raises(NoHostsError) do
        @cmd_class.new(Dk::Local::CmdSpy, @cmd_str, :hosts => Factory.integer)
      end
      assert_raises(NoHostsError) do
        @cmd_class.new(Dk::Local::CmdSpy, @cmd_str, :hosts => [])
      end
      assert_raises(NoHostsError) do
        @cmd_class.new(Dk::Local::CmdSpy, @cmd_str, :hosts => [nil])
      end
      assert_raises(NoHostsError) do
        @cmd_class.new(Dk::Local::CmdSpy, @cmd_str, :hosts => [Factory.string, nil])
      end
      assert_raises(NoHostsError) do
        @cmd_class.new(Dk::Local::CmdSpy, @cmd_str, :hosts => [nil, Factory.string])
      end
    end

    should "know its ssh args" do
      assert_equal @ssh_args,      subject.ssh_args
      assert_equal @host_ssh_args, subject.host_ssh_args
    end

    should "know its cmd str" do
      assert_equal @cmd_str,        subject.cmd_str
      assert_equal subject.cmd_str, subject.to_s
    end

    should "build a local cmd for each of its hosts" do
      subject.hosts.each do |host|
        assert_instance_of Dk::Local::CmdSpy, subject.local_cmds[host]
        exp = ssh_cmd_str(@cmd_str, host, subject.ssh_args, subject.host_ssh_args)
        assert_equal exp, subject.local_cmds[host].cmd_str
      end
      exp_cmd_str = ssh_cmd_str(
        @cmd_str,
        subject.hosts.last,
        subject.ssh_args,
        subject.host_ssh_args
      )
      exp_opts = {
        :env          => @opts[:env],
        :dry_tree_run => @opts[:dry_tree_run]
      }
      assert_equal [exp_cmd_str, exp_opts], @local_cmd_spy_new_called_with

      cmd = @cmd_class.new(Dk::Local::Cmd, @cmd_str, @opts)
      cmd.hosts.each do |host|
        assert_instance_of Dk::Local::Cmd, cmd.local_cmds[host]
        exp = ssh_cmd_str(@cmd_str, host, cmd.ssh_args, cmd.host_ssh_args)
        assert_equal exp, cmd.local_cmds[host].cmd_str
      end
      exp_cmd_str = ssh_cmd_str(
        @cmd_str,
        cmd.hosts.last,
        cmd.ssh_args,
        cmd.host_ssh_args
      )
      exp_opts = {
        :env          => @opts[:env],
        :dry_tree_run => @opts[:dry_tree_run]
      }
      assert_equal [exp_cmd_str, exp_opts], @local_cmd_new_called_with
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
        subject.local_cmds[host].output_lines.each do |ol|
          exp << [host, ol]
        end
      end
      output_lines = subject.output_lines

      assert_equal exp.size, output_lines.size

      if output_lines.size > 0
        assert_instance_of BaseCmd::OutputLine, output_lines.sample
      end

      assert_equal exp.map{ |(h, ol)| h },       output_lines.map(&:host)
      assert_equal exp.map{ |(h, ol)| ol.name }, output_lines.map(&:name)
      assert_equal exp.map{ |(h, ol)| ol.line }, output_lines.map(&:line)
    end

  end

  class CmdTests < UnitTests
    desc "Cmd"
    setup do
      @cmd_class = @remote_class::Cmd
      @cmd = @cmd_class.new(@cmd_str, :hosts => @hosts)
    end
    subject{ @cmd }

    should "build a local cmd for each host with the cmd str, given opts" do
      subject.hosts.each do |host|
        assert_instance_of Dk::Local::Cmd, subject.local_cmds[host]
        exp = ssh_cmd_str(@cmd_str, host, subject.ssh_args, subject.host_ssh_args)
        assert_equal exp, subject.local_cmds[host].cmd_str
      end
      exp_cmd_str = ssh_cmd_str(
        @cmd_str,
        subject.hosts.last,
        subject.ssh_args,
        subject.host_ssh_args
      )
      exp_opts = {
        :env          => nil,
        :dry_tree_run => nil
      }
      assert_equal [exp_cmd_str, exp_opts], @local_cmd_new_called_with

      cmd  = @cmd_class.new(@cmd_str, @opts)
      cmd.hosts.each do |host|
        assert_instance_of Dk::Local::Cmd, cmd.local_cmds[host]
        exp = ssh_cmd_str(@cmd_str, host, cmd.ssh_args, cmd.host_ssh_args)
        assert_equal exp, cmd.local_cmds[host].cmd_str
      end
      exp_cmd_str = ssh_cmd_str(
        @cmd_str,
        cmd.hosts.last,
        cmd.ssh_args,
        cmd.host_ssh_args
      )
      exp_opts = {
        :env          => @opts[:env],
        :dry_tree_run => @opts[:dry_tree_run]
      }
      assert_equal [exp_cmd_str, exp_opts], @local_cmd_new_called_with
    end

  end

  class CmdSpyTests < UnitTests
    desc "CmdSpy"
    setup do
      @cmd_class = @remote_class::CmdSpy
      @cmd = @cmd_class.new(@cmd_str, :hosts => @hosts)
    end
    subject{ @cmd }

    should have_readers :cmd_opts
    should have_imeths :run_input, :stdout=, :stderr=, :exitstatus=
    should have_imeths :run_calls, :run_called?, :ssh?

    should "build a local cmd spy for each host with the cmd str, given opts" do
      subject.hosts.each do |host|
        assert_instance_of Dk::Local::CmdSpy, subject.local_cmds[host]
        exp = ssh_cmd_str(@cmd_str, host, subject.ssh_args, subject.host_ssh_args)
        assert_equal exp, subject.local_cmds[host].cmd_str
      end
      exp_cmd_str = ssh_cmd_str(
        @cmd_str,
        subject.hosts.last,
        subject.ssh_args,
        subject.host_ssh_args
      )
      exp_opts = {
        :env          => nil,
        :dry_tree_run => nil
      }
      assert_equal [exp_cmd_str, exp_opts], @local_cmd_spy_new_called_with

      cmd = @cmd_class.new(@cmd_str, @opts)
      cmd.hosts.each do |host|
        assert_instance_of Dk::Local::CmdSpy, cmd.local_cmds[host]
        exp = ssh_cmd_str(@cmd_str, host, cmd.ssh_args, cmd.host_ssh_args)
        assert_equal exp, cmd.local_cmds[host].cmd_str
      end
      exp_cmd_str = ssh_cmd_str(
        @cmd_str,
        cmd.hosts.last,
        cmd.ssh_args,
        cmd.host_ssh_args
      )
      exp_opts = {
        :env          => @opts[:env],
        :dry_tree_run => @opts[:dry_tree_run]
      }
      assert_equal [exp_cmd_str, exp_opts], @local_cmd_spy_new_called_with
    end

    should "know the input it was run with" do
      input = Factory.string

      assert_nil subject.run_input
      subject.run(input)
      assert_equal input, subject.run_input
    end

    should "demeter its first local cmd spy" do
      first_local_cmd_spy = subject.local_cmds[subject.hosts.first]

      stdout = Factory.stdout
      subject.stdout = stdout
      assert_equal stdout, first_local_cmd_spy.scmd.stdout

      stderr = Factory.stderr
      subject.stderr = stderr
      assert_equal stderr, first_local_cmd_spy.scmd.stderr

      exitstatus = Factory.exitstatus
      subject.exitstatus = exitstatus
      assert_equal exitstatus, first_local_cmd_spy.scmd.exitstatus

      subject.run
      assert_equal first_local_cmd_spy.scmd.start_calls,   subject.run_calls
      assert_equal first_local_cmd_spy.scmd.start_called?, subject.run_called?
    end

    should "be ssh" do
      assert_true subject.ssh?
    end

  end

end
