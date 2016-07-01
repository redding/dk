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
    end
    subject{ @cmd }

  end

  class BaseCmdTests < UnitTests
    desc "BaseCmd"
    setup do
      @cmd_class = Dk::Local::BaseCmd
      @cmd = @cmd_class.new(@scmd_spy)
    end

    should have_readers :scmd
    should have_imeths :cmd_str, :run, :run!, :stdout, :stderr, :success?
    should have_imeths :to_s, :output_lines

    should "know its scmd" do
      assert_equal @scmd_spy, subject.scmd
    end

    should "demeter its scmd" do
      assert_equal @scmd_spy.cmd_str, subject.cmd_str

      assert_false @scmd_spy.run_called?
      subject.run
      assert_true @scmd_spy.run_called?

      assert_false @scmd_spy.run_bang_called?
      subject.run!
      assert_true @scmd_spy.run_bang_called?

      assert_equal @scmd_spy.stdout,   subject.stdout
      assert_equal @scmd_spy.stderr,   subject.stderr
      assert_equal @scmd_spy.success?, subject.success?
      assert_equal @scmd_spy.to_s,     subject.to_s
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

      @scmd_new_called_with = nil
      Assert.stub(Scmd, :new) do |*args|
        @scmd_new_called_with = args
        @scmd_spy
      end

      @cmd = @cmd_class.new(@cmd_str)
    end

    should "build an scmd with the cmd str and any given :env option" do
      assert_equal [@cmd_str, { :env => nil }], @scmd_new_called_with

      opts = {
        :env           => Factory.string,
        Factory.string => Factory.string
      }
      @cmd_class.new(@cmd_str, opts)
      assert_equal [@cmd_str, { :env => opts[:env] }], @scmd_new_called_with
    end

  end

  class CmdSpyTests < UnitTests
    desc "CmdSpy"
    setup do
      @cmd_class = Dk::Local::CmdSpy

      @scmd_spy_new_called_with = nil
      Assert.stub(Scmd::CommandSpy, :new) do |*args|
        @scmd_spy_new_called_with = args
        @scmd_spy
      end

      @cmd = @cmd_class.new(@cmd_str)
    end

    should have_readers :cmd_opts
    should have_imeths :stdout=, :stderr=, :exitstatus=
    should have_imeths :run_calls, :run_bang_calls
    should have_imeths :run_called?, :run_bang_called?

    should "build an scmd spy with the cmd str and any given options" do
      assert_equal [@cmd_str, nil], @scmd_spy_new_called_with
      assert_nil subject.cmd_opts

      opts = { Factory.string => Factory.string }
      cmd  = @cmd_class.new(@cmd_str, opts)
      assert_equal [@cmd_str, opts], @scmd_spy_new_called_with
      assert_equal opts, cmd.cmd_opts
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

      assert_equal @scmd_spy.run_calls,        subject.run_calls
      assert_equal @scmd_spy.run_bang_calls,   subject.run_bang_calls
      assert_equal @scmd_spy.run_called?,      subject.run_called?
      assert_equal @scmd_spy.run_bang_called?, subject.run_bang_called?
    end

  end

end
