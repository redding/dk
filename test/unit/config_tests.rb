require 'assert'
require 'dk/config'

require 'dk/has_set_param'
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

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @config = @config_class.new
    end
    subject{ @config }

    should have_readers :init_procs, :params
    should have_imeths :init
    should have_imeths :before, :after, :prepend_before, :prepend_after
    should have_imeths :ssh_hosts, :ssh_args

    should "default its attrs" do
      assert_equal [], subject.init_procs

      exp = {}
      assert_equal exp, subject.params
    end

    should "instance eval its init procs on init" do
      init_self = nil
      subject.init_procs << proc{ init_self = self }

      subject.init
      assert_equal @config, init_self
    end

    should "append callback tasks to other tasks" do
      subj_task_class = Class.new{ include Dk::Task }
      cb_task_class   = Factory.string
      cb_params       = Factory.string

      subj_task_class.before_callbacks << Factory.string
      subject.before(subj_task_class, cb_task_class, cb_params)
      assert_equal cb_task_class, subj_task_class.before_callbacks.last.task_class
      assert_equal cb_params,     subj_task_class.before_callbacks.last.params

      subj_task_class.after_callbacks << Factory.string
      subject.after(subj_task_class, cb_task_class, cb_params)
      assert_equal cb_task_class, subj_task_class.after_callbacks.last.task_class
      assert_equal cb_params,     subj_task_class.after_callbacks.last.params
    end

    should "prepend callback tasks to other tasks" do
      subj_task_class = Class.new{ include Dk::Task }
      cb_task_class   = Factory.string
      cb_params       = Factory.string

      subj_task_class.before_callbacks << Factory.string
      subject.prepend_before(subj_task_class, cb_task_class, cb_params)
      assert_equal cb_task_class, subj_task_class.before_callbacks.first.task_class
      assert_equal cb_params,     subj_task_class.before_callbacks.first.params

      subj_task_class.after_callbacks << Factory.string
      subject.prepend_after(subj_task_class, cb_task_class, cb_params)
      assert_equal cb_task_class, subj_task_class.after_callbacks.first.task_class
      assert_equal cb_params,     subj_task_class.after_callbacks.first.params
    end

    should "know its ssh hosts" do
      group_name = Factory.string
      hosts      = Factory.hosts

      assert_equal Hash.new, subject.ssh_hosts
      assert_nil subject.ssh_hosts(group_name)

      assert_equal hosts, subject.ssh_hosts(group_name, hosts)
      assert_equal hosts, subject.ssh_hosts(group_name)

      exp = { group_name => hosts }
      assert_equal exp, subject.ssh_hosts
    end

    should "know its ssh args" do
      args = Factory.string

      assert_equal "",   subject.ssh_args
      assert_equal args, subject.ssh_args(args)
      assert_equal args, subject.ssh_args
    end

  end

end
