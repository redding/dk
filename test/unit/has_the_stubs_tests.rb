require 'assert'
require 'dk/has_the_stubs'

require 'dk/local'
require 'dk/remote'

module Dk::HasTheStubs

  class UnitTests < Assert::Context
    desc "Dk::HasTheStubs"
    setup do
      @module = Dk::HasTheStubs
    end
    subject{ @module }

    should "use much-plugin" do
      assert_includes MuchPlugin, subject
    end

  end

  class MixinTests < UnitTests
    desc "mixed in"
    setup do
      @class = Class.new do
        include Dk::HasTheStubs

        def has_the_stubs_build_local_cmd(cmd_str, given_opts)
          BuiltCmd.new(cmd_str, given_opts)
        end

        def has_the_stubs_build_remote_cmd(cmd_str, ssh_opts)
          BuiltCmd.new(cmd_str, ssh_opts)
        end
      end
    end
    subject{ @class }

  end

  class InitTests < MixinTests
    desc "when init"
    setup do
      raw_cmd_str    = Factory.string
      raw_input      = Factory.string
      raw_given_opts = { Factory.string => Factory.string }

      @cmd_str    = [raw_cmd_str, proc{ "#{raw_cmd_str},#{some_attr}" }].sample
      @input      = [raw_input,   proc{ "#{raw_input},#{some_attr}" }].sample
      @given_opts = [
        raw_given_opts,
        proc{ raw_given_opts.merge('some_attr' => some_attr) }
      ].sample
      @ssh_opts   = { :hosts => Factory.hosts }
      @stub_block = Proc.new{ |s| Factory.string }

      task_class = Class.new{ def some_attr; @some_attr ||= Factory.string; end }
      @task      = task_class.new
      @instance  = @class.new
    end
    subject{ @instance }

    should have_imeths :local_cmd_stubs, :stub_cmd, :unstub_all_cmds
    should have_imeths :remote_cmd_stubs, :stub_ssh, :unstub_all_ssh

    should "allow stubbing cmds" do
      assert_equal 0, subject.local_cmd_stubs.size

      cmd_str    = get_raw_value(@cmd_str)
      input      = get_raw_value(@input)
      given_opts = get_raw_value(@given_opts)

      subject.stub_cmd(@cmd_str, &@stub_block)
      assert_equal 1, subject.local_cmd_stubs.size
      assert_equal @stub_block, lookup_cmd_stub_block(cmd_str, nil, nil)

      subject.stub_cmd(@cmd_str, :input => @input, &@stub_block)
      assert_equal 2, subject.local_cmd_stubs.size
      assert_equal @stub_block, lookup_cmd_stub_block(cmd_str, input, nil)

      subject.stub_cmd(@cmd_str, :opts => @given_opts, &@stub_block)
      assert_equal 3, subject.local_cmd_stubs.size
      assert_equal @stub_block, lookup_cmd_stub_block(cmd_str, nil, given_opts)

      subject.stub_cmd(@cmd_str, {
        :input => @input,
        :opts  => @given_opts
      }, &@stub_block)
      assert_equal 4, subject.local_cmd_stubs.size
      assert_equal @stub_block, lookup_cmd_stub_block(cmd_str, input, given_opts)
    end

    should "allow unstubbing all cmds" do
      subject.stub_cmd(@cmd_str, &@stub_block)
      subject.stub_cmd(@cmd_str, :input => @input, &@stub_block)
      subject.stub_cmd(@cmd_str, :opts  => @given_opts, &@stub_block)
      subject.stub_cmd(@cmd_str, {
        :input => @input,
        :opts  => @given_opts
      }, &@stub_block)

      assert_equal 4, subject.local_cmd_stubs.size
      subject.unstub_all_cmds
      assert_equal 0, subject.local_cmd_stubs.size
    end

    should "allow stubbing ssh" do
      assert_equal 0, subject.remote_cmd_stubs.size

      cmd_str    = get_raw_value(@cmd_str)
      input      = get_raw_value(@input)
      given_opts = get_raw_value(@given_opts)

      subject.stub_ssh(@cmd_str, &@stub_block)
      assert_equal 1, subject.remote_cmd_stubs.size
      assert_equal @stub_block, lookup_ssh_stub_block(cmd_str, nil, nil)

      subject.stub_ssh(@cmd_str, :input => @input, &@stub_block)
      assert_equal 2, subject.remote_cmd_stubs.size
      assert_equal @stub_block, lookup_ssh_stub_block(cmd_str, input, nil)

      subject.stub_ssh(@cmd_str, :opts => @given_opts, &@stub_block)
      assert_equal 3, subject.remote_cmd_stubs.size
      assert_equal @stub_block, lookup_ssh_stub_block(cmd_str, nil, given_opts)

      subject.stub_ssh(@cmd_str, {
        :input => @input,
        :opts  => @given_opts
      }, &@stub_block)
      assert_equal 4, subject.remote_cmd_stubs.size
      assert_equal @stub_block, lookup_ssh_stub_block(cmd_str, input, given_opts)
    end

    should "allow unstubbing all ssh" do
      subject.stub_ssh(@cmd_str, &@stub_block)
      subject.stub_ssh(@cmd_str, :input => @input, &@stub_block)
      subject.stub_ssh(@cmd_str, :opts  => @given_opts, &@stub_block)
      subject.stub_ssh(@cmd_str, {
        :input => @input,
        :opts  => @given_opts
      }, &@stub_block)

      assert_equal 4, subject.remote_cmd_stubs.size
      subject.unstub_all_ssh
      assert_equal 0, subject.remote_cmd_stubs.size
    end

    # test the `Runner` interface that this overwrites, these are private
    # methods but since they overwrite the runner's interface we want to test
    # them as if they were public methods

    should "use stubs with `build_local_cmd`" do
      task       = @task
      cmd_str    = get_raw_value(@cmd_str)
      input      = get_raw_value(@input)
      given_opts = get_raw_value(@given_opts)

      subject.stub_cmd(@cmd_str){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval do
        build_local_cmd(task, cmd_str, nil, nil)
      end
      assert_false spy.success?

      subject.unstub_all_cmds
      subject.stub_cmd(@cmd_str, :input => @input){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval do
        build_local_cmd(task, cmd_str, input, nil)
      end
      assert_false spy.success?

      subject.unstub_all_cmds
      subject.stub_cmd(@cmd_str, :opts => @given_opts){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval do
        build_local_cmd(task, cmd_str, nil, given_opts)
      end
      assert_false spy.success?

      subject.unstub_all_cmds
      subject.stub_cmd(@cmd_str, {
        :input => @input,
        :opts  => @given_opts
      }){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval do
        build_local_cmd(task, cmd_str, input, given_opts)
      end
      assert_false spy.success?
    end

    should "defer to `has_the_stubs_build_local_cmd` when cmd isn't stubbed" do
      task       = @task
      cmd_str    = get_raw_value(@cmd_str)
      input      = get_raw_value(@input)
      given_opts = get_raw_value(@given_opts)

      result = subject.instance_eval do
        build_local_cmd(task, cmd_str, input, given_opts)
      end
      assert_equal BuiltCmd.new(cmd_str, given_opts), result
    end

    should "use stubs with `build_remote_cmd`" do
      task       = @task
      cmd_str    = get_raw_value(@cmd_str)
      input      = get_raw_value(@input)
      given_opts = get_raw_value(@given_opts)
      ssh_opts   = @ssh_opts

      subject.stub_ssh(@cmd_str){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval do
        build_remote_cmd(task, cmd_str, nil, nil, ssh_opts)
      end
      assert_false spy.success?

      subject.unstub_all_ssh
      subject.stub_ssh(@cmd_str, :input => @input){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval do
        build_remote_cmd(task, cmd_str, input, nil, ssh_opts)
      end
      assert_false spy.success?

      subject.unstub_all_ssh
      subject.stub_ssh(@cmd_str, :opts => @given_opts){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval do
        build_remote_cmd(task, cmd_str, nil, given_opts, ssh_opts)
      end
      assert_false spy.success?

      subject.unstub_all_ssh
      subject.stub_ssh(@cmd_str, {
        :input => @input,
        :opts  => @given_opts
      }){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval do
        build_remote_cmd(task, cmd_str, input, given_opts, ssh_opts)
      end
      assert_false spy.success?
    end

    should "defer to `has_the_stubs_build_remote_cmd` when cmd isn't stubbed" do
      task       = @task
      cmd_str    = get_raw_value(@cmd_str)
      input      = get_raw_value(@input)
      given_opts = get_raw_value(@given_opts)
      ssh_opts   = @ssh_opts

      result = subject.instance_eval do
        build_remote_cmd(task, cmd_str, input, given_opts, ssh_opts)
      end
      assert_equal BuiltCmd.new(cmd_str, ssh_opts), result
    end

    private

    def get_raw_value(value)
      value.kind_of?(::Proc) ? @task.instance_eval(&value) : value
    end

    def lookup_cmd_stub_block(cmd_str, input, given_opts)
      instance = subject
      task     = @task
      subject.instance_eval do
        find_cmd_ssh_stub_block(instance.local_cmd_stubs, task, cmd_str, input, given_opts)
      end
    end

    def lookup_ssh_stub_block(cmd_str, input, given_opts)
      instance = subject
      task     = @task
      subject.instance_eval do
        find_cmd_ssh_stub_block(instance.remote_cmd_stubs, task, cmd_str, input, given_opts)
      end
    end

  end

  BuiltCmd = Struct.new(:cmd_str, :opts)

end

