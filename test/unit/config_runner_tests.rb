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
      @name       = ['before', 'after'].sample
      @task_class = Factory.string
      @callbacks  = Factory.integer(3).times.map{ Factory.string }

      @config = Dk::Config.new

      @callbacks.each do |callback_task_class|
        @config.send(@name, @task_class, callback_task_class)
        @config.send("prepend_#{@name}", @task_class, callback_task_class)
      end
    end

    should "initialize using the config's values" do
      runner = @runner_class.new(@config)

      assert_equal @config.params,        runner.params
      assert_equal @config.ssh_hosts,     runner.ssh_hosts
      assert_equal @config.ssh_args,      runner.ssh_args
      assert_equal @config.host_ssh_args, runner.host_ssh_args
      assert_equal @config.dk_logger,     runner.logger

      exp = @callbacks
      assert_equal exp, runner.task_callbacks(@name, @task_class).map(&:task_class)
      exp = @callbacks.reverse
      assert_equal exp, runner.task_callbacks("prepend_#{@name}", @task_class).map(&:task_class)
    end

    should "honor any custom logger option" do
      logger = Factory.string
      runner = @runner_class.new(@config, :logger => logger)
      assert_equal logger, runner.logger
    end

  end

end
