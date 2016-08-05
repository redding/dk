require 'assert'
require 'dk/config'

require 'logsly'
require 'dk/has_set_param'
require 'dk/has_ssh_opts'
require 'dk/task'

class Dk::Config

  class UnitTests < Assert::Context
    desc "Dk::Config"
    setup do
      @config_class = Dk::Config
    end
    subject{ @config_class }

    should "include HasSetParam" do
      assert_includes Dk::HasSetParam, subject
    end

    should "include HasSSHOpts" do
      assert_includes Dk::HasSSHOpts, subject
    end

    should "know its defaults" do
      assert_equal Array.new,          subject::DEFAULT_INIT_PROCS
      assert_equal Hash.new,           subject::DEFAULT_PARAMS
      assert_equal Hash.new,           subject::DEFAULT_CALLBACKS
      assert_equal Hash.new,           subject::DEFAULT_SSH_HOSTS
      assert_equal '',                 subject::DEFAULT_SSH_ARGS
      assert_equal Hash.new,           subject::DEFAULT_HOST_SSH_ARGS
      assert_equal Hash.new,           subject::DEFAULT_TASKS
      assert_equal "%m\n",             subject::DEFAULT_LOG_PATTERN
      assert_equal '[%d %-5l] : %m\n', subject::DEFAULT_LOG_FILE_PATTERN
      assert_equal 'info',             subject::DEFAULT_STDOUT_LOG_LEVEL
    end

    should "know the file output log level" do
      assert_equal 'debug', subject::FILE_LOG_LEVEL
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @config = @config_class.new
    end
    subject{ @config }

    should have_readers :init_procs, :params
    should have_readers :before_callbacks, :prepend_before_callbacks
    should have_readers :after_callbacks, :prepend_after_callbacks
    should have_readers :tasks
    should have_imeths :init
    should have_imeths :before, :prepend_before, :after, :prepend_after
    should have_imeths :before_callback_task_classes
    should have_imeths :prepend_before_callback_task_classes
    should have_imeths :after_callback_task_classes
    should have_imeths :prepend_after_callback_task_classes
    should have_imeths :task, :stdout_log_level
    should have_imeths :log_pattern, :log_file, :log_file_pattern
    should have_imeths :dk_logger_stdout_output_name, :dk_logger_file_output_name
    should have_imeths :dk_logger

    should "default its attrs" do
      assert_equal @config_class::DEFAULT_INIT_PROCS,       subject.init_procs
      assert_equal @config_class::DEFAULT_PARAMS,           subject.params
      assert_equal @config_class::DEFAULT_CALLBACKS,        subject.before_callbacks
      assert_equal @config_class::DEFAULT_CALLBACKS,        subject.prepend_before_callbacks
      assert_equal @config_class::DEFAULT_CALLBACKS,        subject.after_callbacks
      assert_equal @config_class::DEFAULT_CALLBACKS,        subject.prepend_after_callbacks
      assert_equal @config_class::DEFAULT_SSH_HOSTS,        subject.ssh_hosts
      assert_equal @config_class::DEFAULT_SSH_ARGS,         subject.ssh_args
      assert_equal @config_class::DEFAULT_HOST_SSH_ARGS,    subject.host_ssh_args
      assert_equal @config_class::DEFAULT_TASKS,            subject.tasks
      assert_equal @config_class::DEFAULT_STDOUT_LOG_LEVEL, subject.stdout_log_level
      assert_equal @config_class::DEFAULT_LOG_PATTERN,      subject.log_pattern
      assert_equal @config_class::DEFAULT_LOG_FILE_PATTERN, subject.log_file_pattern

      assert_nil subject.log_file
    end

    should "instance eval its init procs on init" do
      init_self = nil
      subject.init_procs << proc{ init_self = self }

      subject.init
      assert_equal @config, init_self
    end

    should "append callback tasks to other tasks" do
      subj_task_class  = Class.new{ include Dk::Task }
      other_task_class = Factory.string
      cb_task_class    = Factory.string
      cb_params        = Factory.string

      subject.before(subj_task_class, other_task_class)
      subject.before(subj_task_class, cb_task_class, cb_params)

      cb = subject.before_callbacks[subj_task_class].last
      assert_equal cb_task_class, cb.task_class
      assert_equal cb_params,     cb.params

      subject.after(subj_task_class, other_task_class)
      subject.after(subj_task_class, cb_task_class, cb_params)

      cb = subject.after_callbacks[subj_task_class].last
      assert_equal cb_task_class, cb.task_class
      assert_equal cb_params,     cb.params

      exp = [other_task_class, cb_task_class]
      assert_equal exp, subject.before_callback_task_classes(subj_task_class)
      assert_equal exp, subject.after_callback_task_classes(subj_task_class)
    end

    should "prepend callback tasks to other tasks" do
      subj_task_class  = Class.new{ include Dk::Task }
      other_task_class = Factory.string
      cb_task_class    = Factory.string
      cb_params        = Factory.string

      subject.prepend_before(subj_task_class, other_task_class)
      subject.prepend_before(subj_task_class, cb_task_class, cb_params)

      cb = subject.prepend_before_callbacks[subj_task_class].first
      assert_equal cb_task_class, cb.task_class
      assert_equal cb_params,     cb.params

      subject.prepend_after(subj_task_class, other_task_class)
      subject.prepend_after(subj_task_class, cb_task_class, cb_params)

      cb = subject.prepend_after_callbacks[subj_task_class].first
      assert_equal cb_task_class, cb.task_class
      assert_equal cb_params,     cb.params

      exp = [other_task_class, cb_task_class].reverse
      assert_equal exp, subject.prepend_before_callback_task_classes(subj_task_class)
      assert_equal exp, subject.prepend_after_callback_task_classes(subj_task_class)
    end

    should "not duplicate callback tasks if they've already been added" do
      subj_task_class  = Class.new{ include Dk::Task }
      other_task_class = Factory.string
      cb_task_class    = Factory.string
      cb_params        = Factory.string

      subject.before(subj_task_class, other_task_class)
      subject.before(subj_task_class, other_task_class)
      assert_equal 1, subject.before_callbacks[subj_task_class].size

      subject.before(subj_task_class, cb_task_class, cb_params)
      subject.before(subj_task_class, cb_task_class, cb_params)
      assert_equal 2, subject.before_callbacks[subj_task_class].size

      subject.after(subj_task_class, other_task_class)
      subject.after(subj_task_class, other_task_class)
      assert_equal 1, subject.after_callbacks[subj_task_class].size

      subject.after(subj_task_class, cb_task_class, cb_params)
      subject.after(subj_task_class, cb_task_class, cb_params)
      assert_equal 2, subject.after_callbacks[subj_task_class].size

      subject.prepend_before(subj_task_class, other_task_class)
      subject.prepend_before(subj_task_class, other_task_class)
      assert_equal 1, subject.prepend_before_callbacks[subj_task_class].size

      subject.prepend_before(subj_task_class, cb_task_class, cb_params)
      subject.prepend_before(subj_task_class, cb_task_class, cb_params)
      assert_equal 2, subject.prepend_before_callbacks[subj_task_class].size

      subject.prepend_after(subj_task_class, other_task_class)
      subject.prepend_after(subj_task_class, other_task_class)
      assert_equal 1, subject.prepend_after_callbacks[subj_task_class].size

      subject.prepend_after(subj_task_class, cb_task_class, cb_params)
      subject.prepend_after(subj_task_class, cb_task_class, cb_params)
      assert_equal 2, subject.prepend_after_callbacks[subj_task_class].size
    end

    should "add callable tasks" do
      assert_empty subject.tasks

      task_name  = Factory.string
      task_class = Class.new{ include Dk::Task }
      subject.task(task_name, task_class)

      assert_equal task_class, subject.task(task_name)
    end

    should "complain when adding a callable task that isn't a Dk::Task" do
      assert_raises(ArgumentError) do
        subject.task(Factory.string, Factory.string)
      end
      assert_raises(ArgumentError) do
        subject.task(Factory.string, Class.new)
      end
    end

    should "complain when looking up a named task that hasn't been configured" do
      assert_raises(UnknownTaskError) do
        subject.task(Factory.string)
      end
    end

    should "know its stdout log level" do
      level = Factory.string

      assert_equal @config_class::DEFAULT_STDOUT_LOG_LEVEL, subject.stdout_log_level
      assert_equal level, subject.stdout_log_level(level)
      assert_equal level, subject.stdout_log_level
    end

    should "know its log pattern" do
      pattern = Factory.string

      assert_equal @config_class::DEFAULT_LOG_PATTERN, subject.log_pattern
      assert_equal pattern, subject.log_pattern(pattern)
      assert_equal pattern, subject.log_pattern
    end

    should "know its log file" do
      file = Factory.file_path

      assert_nil subject.log_file
      assert_equal file, subject.log_file(file)
      assert_equal file, subject.log_file
    end

    should "know its log file pattern" do
      pattern = Factory.string

      assert_equal @config_class::DEFAULT_LOG_FILE_PATTERN, subject.log_file_pattern
      assert_equal pattern, subject.log_file_pattern(pattern)
      assert_equal pattern, subject.log_file_pattern
    end

    should "know its logger output names" do
      exp = "dk-config-#{subject.object_id}-stdout"
      assert_equal exp, subject.dk_logger_stdout_output_name

      exp = "dk-config-#{subject.object_id}-file"
      assert_equal exp, subject.dk_logger_file_output_name
    end

    should "know its logger" do
      logger = subject.dk_logger

      assert_instance_of LogslyLogger, logger
      assert_equal subject, logger.config
    end

  end

  class LogslyLoggerTests < UnitTests
    desc "LogslyLogger"
    setup do
      @logger_class = LogslyLogger
    end
    subject{ @logger_class }

    should "be a logsly logger and know its log type" do
      assert_includes Logsly, subject
      assert_equal 'dk', subject::LOG_TYPE
    end

  end

  class LogslyLoggerInitTests < LogslyLoggerTests
    desc "when init"
    setup do
      @config = @config_class.new
      @logger = @logger_class.new(@config)
    end
    subject{ @logger }

    should "know its log type" do
      assert_equal @logger_class::LOG_TYPE, subject.log_type
    end

    should "have only a logsly stdout output" do
      assert_equal 1, subject.outputs.size
      assert_equal @config.dk_logger_stdout_output_name, subject.outputs.first

      out = Logsly.outputs(@config.dk_logger_stdout_output_name)
      assert_instance_of Logsly::Outputs::Stdout, out

      data = out.data(subject)
      assert_equal @config.stdout_log_level, data.level
      assert_equal @config.log_pattern,      data.pattern
    end

  end

  class LogslyLoggerInitWithLogFileTests < LogslyLoggerInitTests
    desc "with a log file"
    setup do
      @config.log_file Factory.log_file
      @logger = @logger_class.new(@config)
    end
    teardown do
      @config.log_file.delete
    end

    should "have a logsly file output in addition to the stdout output" do
      assert_equal 2, subject.outputs.size
      assert_equal @config.dk_logger_stdout_output_name, subject.outputs.first
      assert_equal @config.dk_logger_file_output_name,   subject.outputs.last

      out = Logsly.outputs(@config.dk_logger_file_output_name)
      assert_instance_of Logsly::Outputs::File, out

      data = out.data(subject)
      exp = File.expand_path(@config.log_file, ENV['PWD'])
      assert_equal exp, data.path
      assert_equal @config_class::FILE_LOG_LEVEL, data.level
      assert_equal @config.log_file_pattern,      data.pattern
    end

  end

end
