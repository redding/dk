require 'assert'
require 'dk/cli'

require 'dk/config'
require 'dk/dk_runner'
require 'dk/dry_runner'
require 'dk/task'
require 'dk/tree_runner'
require 'dk/version'

class Dk::CLI

  class UnitTests < Assert::Context
    desc "Dk::CLI"
    setup do
      @cli_class = Dk::CLI
    end
    subject{ @cli_class }

    should have_imeths :run

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @kernel_spy = KernelSpy.new

      @scmd_test_mode = ENV['SCMD_TEST_MODE']
      Dk.reset
      ENV['DK_CONFIG'] = ROOT_PATH.join('test/support/config/tasks.rb').to_s
      @cli = Dk::CLI.new(@kernel_spy)
    end
    teardown do
      Dk.reset
      ENV['SCMD_TEST_MODE'] = @scmd_test_mode
    end
    subject{ @cli }

    should have_readers :clirb
    should have_imeths :run

    should "know its clirb" do
      assert_instance_of Dk::CLIRB, subject.clirb
    end

  end

  class RunTests < InitTests
    desc "and run with a configured task name"
    setup do
      @runner_init_with = nil
      @runner_runs  = []
      Assert.stub(Dk::DkRunner, :new) do |*args|
        @runner_init_with = args

        runner = Assert.stub_send(Dk::DkRunner, :new, *args)
        Assert.stub(runner, :run){ |*args| @runner_runs << args }
        runner
      end
      @cli.run('cli-test-task', 'cli-other-task')
    end

    should "build live runner, not disable scmd and run the named tasks and exit" do
      assert_equal [Dk.config],     @runner_init_with
      assert_equal @scmd_test_mode, ENV['SCMD_TEST_MODE']

      assert_equal 2, @runner_runs.size
      assert_equal [CLITestTask],  @runner_runs.first
      assert_equal [CLIOtherTask], @runner_runs.last

      assert_equal 0, @kernel_spy.exit_status
    end

  end

  class RunWithDryRunFlagTests < InitTests
    desc "and run with the --dry-run flag"
    setup do
      @runner_init_with = nil
      @runner_run_with  = nil
      Assert.stub(Dk::DryRunner, :new) do |*args|
        @runner_init_with = args

        runner = Assert.stub_send(Dk::DryRunner, :new, *args)
        Assert.stub(runner, :run){ |*args| @runner_run_with = args }
        runner
      end
      @cli.run('cli-test-task', '--dry-run')
    end

    should "build dry runner, disable scmd and run the named task and exit" do
      assert_equal [Dk.config],   @runner_init_with
      assert_equal '1',           ENV['SCMD_TEST_MODE']
      assert_equal [CLITestTask], @runner_run_with

      assert_equal 0, @kernel_spy.exit_status
    end

  end

  class RunWithDryTreeFlagTests < InitTests
    desc "and run with the --tree flag"
    setup do
      @runner_init_with = nil
      @runner_run_with  = nil
      Assert.stub(Dk::TreeRunner, :new) do |*args|
        @runner_init_with = args

        runner = Assert.stub_send(Dk::TreeRunner, :new, *args)
        Assert.stub(runner, :run){ |*args| @runner_run_with = args }
        runner
      end
      @cli.run('cli-test-task', '--tree')
    end

    should "build tree runner, disable scmd and run the named task and exit" do
      assert_equal [Dk.config, @kernel_spy], @runner_init_with
      assert_equal '1',                      ENV['SCMD_TEST_MODE']
      assert_equal [CLITestTask],            @runner_run_with

      assert_equal 0, @kernel_spy.exit_status
    end

  end

  class RunWithDashTFlagTests < InitTests
    desc "and run with the -T flag"
    setup do
      @cli.run(['-T', '--list-tasks'].sample)
    end

    should "list out the callable task details and exit" do
      max   = Dk.config.tasks.keys.map(&:size).max
      tasks = Dk.config.tasks.map do |(name, task_class)|
        "#{name.ljust(max)} # #{task_class.description}"
      end

      exp = "#{tasks.sort.join("\n")}\n"
      assert_equal exp, @kernel_spy.output
      assert_equal 0,   @kernel_spy.exit_status
    end

  end

  class RunWithVerboseFlagTests < InitTests
    desc "and run with the --verbose flag"
    setup do
      @cli.run('--verbose')
    end

    should "set the stdout log level to 'debug'" do
      assert_equal 'debug', Dk.config.stdout_log_level
    end

  end

  class RunWithHelpFlagTests < InitTests
    desc "and run with the --help flag"
    setup do
      @cli.run('--help')
    end

    should "print some help info and exit" do
      max   = Dk.config.tasks.keys.map(&:size).max
      tasks = Dk.config.tasks.map do |(name, task_class)|
        "    #{name.ljust(max)} # #{task_class.description}"
      end

      exp = "Usage: dk [TASKS] [options]\n\n" \
            "Tasks:\n" \
            "#{tasks.sort.join("\n")}\n\n" \
            "Options: #{subject.clirb.to_s}"
      assert_equal exp, @kernel_spy.output
      assert_equal 0,   @kernel_spy.exit_status
    end

  end

  class RunWithVersionFlagTests < InitTests
    desc "and run with the --version flag"
    setup do
      @cli.run('--version')
    end

    should "print some help info and exit" do
      exp = "#{Dk::VERSION}\n"
      assert_equal exp, @kernel_spy.output
      assert_equal 0,   @kernel_spy.exit_status
    end

  end

  class RunWithUnknownTaskTests < InitTests
    desc "and run with an unknown task"
    setup do
      @task_name = Factory.string
      @cli.run(@task_name)
    end

    should "output to the user that the task is not known and exit" do
      exp = "No task named #{@task_name.inspect}"
      assert_includes exp, @kernel_spy.output
      assert_equal 1, @kernel_spy.exit_status
    end

  end

  class RunWithInvalidOptionTests < InitTests
    desc "and run with an invalid option"
    setup do
      @option_name = "--#{Factory.string}"
      @cli.run(@option_name)
    end

    should "output to the user that the option is invalid and exit" do
      exp = "invalid option: #{@option_name}"
      assert_includes exp, @kernel_spy.output
      assert_equal 1, @kernel_spy.exit_status
    end

  end

  class RunWithAnErrorTests < InitTests
    desc "and run with an error"
    setup do
      Assert.stub(subject.clirb, :parse!){ raise StandardError, 'test' }
      @cli.run
    end

    should "output the error and exit" do
      exp = "StandardError: test\n"
      assert_includes exp, @kernel_spy.output
      assert_equal 1, @kernel_spy.exit_status
    end

  end

  class KernelSpy
    def initialize
      @output = StringIO.new
      @exit_statuses = []
    end

    def output
      @output.rewind
      @output.read
    end

    def puts(message)
      @output.puts(message)
    end

    def exit(code)
      @exit_statuses << code
    end

    def exit_status
      @exit_statuses.first
    end
  end

end
