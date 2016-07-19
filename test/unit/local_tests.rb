require 'assert'
require 'dk/local'

require 'scmd/command_spy'

module Dk::Local

  class UnitTests < Assert::Context
    desc "Dk::Local"
    setup do
      @cmd_str  = Factory.string
      @scmd_spy = Scmd::CommandSpy.new(@cmd_str).tap do |spy|
        spy.exitstatus = Factory.exitstatus
        spy.stdout     = [Factory.stdout, nil].sample
        spy.stderr     = [Factory.stderr, nil].sample
      end

      @scmd_new_called_with = nil
      Assert.stub(Scmd, :new) do |*args|
        @scmd_new_called_with = args
        @scmd_spy
      end

      @scmd_spy_new_called_with = nil
      Assert.stub(Scmd::CommandSpy, :new) do |*args|
        @scmd_spy_new_called_with = args
        @scmd_spy
      end
    end
    subject{ @cmd }

  end

  class BaseCmdTests < UnitTests
    desc "BaseCmd"
    setup do
      @cmd_class = Dk::Local::BaseCmd
      @opts = {
        :env           => Factory.string,
        Factory.string => Factory.string
      }

      @cmd = @cmd_class.new(Scmd, @cmd_str, @opts)
    end

    should have_readers :scmd, :cmd_str
    should have_imeths :to_s, :run, :stdout, :stderr, :success?
    should have_imeths :output_lines

    should "build an scmd with the cmd str and any given :env option" do
      assert_equal @scmd_spy, subject.scmd
      assert_equal [@cmd_str, { :env => @opts[:env] }], @scmd_new_called_with

      cmd = @cmd_class.new(Scmd::CommandSpy, @cmd_str, @opts)
      assert_equal @scmd_spy, cmd.scmd
      assert_equal [@cmd_str, { :env => @opts[:env] }], @scmd_spy_new_called_with
    end

    should "know its cmd str" do
      assert_equal @cmd_str,        subject.cmd_str
      assert_equal subject.cmd_str, subject.to_s
    end

    should "demeter its scmd" do
      assert_false @scmd_spy.run_called?
      input = Factory.string
      subject.run(input)
      assert_true @scmd_spy.run_called?
      assert_equal input, @scmd_spy.run_calls.last.input

      assert_equal @scmd_spy.stdout,   subject.stdout
      assert_equal @scmd_spy.stderr,   subject.stderr
      assert_equal @scmd_spy.success?, subject.success?
    end

    should "know its output lines" do
      stdout_lines = subject.stdout.to_s.split("\n")
      stderr_lines = subject.stderr.to_s.split("\n")
      output_lines = subject.output_lines

      exp = (stdout_lines + stderr_lines).size
      assert_equal exp, output_lines.size

      if output_lines.size > 0
        assert_instance_of BaseCmd::OutputLine, output_lines.sample
      end

      exp = stdout_lines.size.times.map{ 'stdout' } +
            stderr_lines.size.times.map{ 'stderr' }
      assert_equal exp, output_lines.map(&:name)

      exp = stdout_lines + stderr_lines
      assert_equal exp, output_lines.map(&:line)
    end

  end

  class CmdTests < UnitTests
    desc "Cmd"
    setup do
      @cmd_class = Dk::Local::Cmd
      @cmd = @cmd_class.new(@cmd_str)
    end

    should "build an scmd with the cmd str and any given options" do
      assert_equal [@cmd_str, { :env => nil }], @scmd_new_called_with

      opts = { :env => Factory.string }
      cmd  = @cmd_class.new(@cmd_str, opts)
      assert_equal [@cmd_str, { :env => opts[:env] }], @scmd_new_called_with
    end

  end

  class CmdSpyTests < UnitTests
    desc "CmdSpy"
    setup do
      @cmd_class = Dk::Local::CmdSpy
      @cmd = @cmd_class.new(@cmd_str)
    end

    should have_readers :cmd_opts
    should have_imeths :run_input, :stdout=, :stderr=, :exitstatus=
    should have_imeths :run_calls, :run_called?

    should "build an scmd spy with the cmd str and any given options" do
      assert_equal [@cmd_str, { :env => nil }], @scmd_spy_new_called_with
      assert_nil subject.cmd_opts

      opts = { :env => Factory.string }
      cmd  = @cmd_class.new(@cmd_str, opts)
      assert_equal [@cmd_str, { :env => opts[:env] }], @scmd_spy_new_called_with
      assert_equal opts, cmd.cmd_opts
    end

    should "know the input it was run with" do
      input = Factory.string

      assert_nil subject.run_input
      subject.run(input)
      assert_equal input, subject.run_input
    end

    should "demeter its scmd spy" do
      stdout = Factory.stdout
      subject.stdout = stdout
      assert_equal stdout, @scmd_spy.stdout

      stderr = Factory.stderr
      subject.stderr = stderr
      assert_equal stderr, @scmd_spy.stderr

      exitstatus = Factory.exitstatus
      subject.exitstatus = exitstatus
      assert_equal exitstatus, @scmd_spy.exitstatus

      subject.run
      assert_equal @scmd_spy.run_calls,   subject.run_calls
      assert_equal @scmd_spy.run_called?, subject.run_called?
    end

  end

end
