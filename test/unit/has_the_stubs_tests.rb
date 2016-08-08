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
      @cmd_str   = Factory.string
      @cmd_input = Factory.string
      @cmd_opts  = { Factory.string => Factory.string }

      @given_ssh_opts = Factory.ssh_cmd_opts
      @ssh_opts       = { :hosts => Factory.hosts }

      @stub_block = Proc.new{ |s| Factory.string }

      @instance = @class.new
    end
    subject{ @instance }

    should have_imeths :stub_cmd, :unstub_cmd, :unstub_all_cmds, :local_cmd_stubs
    should have_imeths :stub_ssh, :unstub_ssh, :unstub_all_ssh, :remote_cmd_stubs

    should "allow stubbing cmds" do
      assert_equal 0, subject.instance_eval{ local_cmd_stub_blocks.size }

      subject.stub_cmd(@cmd_str, &@stub_block)
      assert_equal 1, subject.instance_eval{ local_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, nil, nil]
      spy_block = subject.instance_eval{ local_cmd_stub_blocks[exp_key] }
      assert_same @stub_block, spy_block

      subject.stub_cmd(@cmd_str, @cmd_input, &@stub_block)
      assert_equal 2, subject.instance_eval{ local_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, @cmd_input, nil]
      spy_block = subject.instance_eval{ local_cmd_stub_blocks[exp_key] }
      assert_same @stub_block, spy_block

      subject.stub_cmd(@cmd_str, @cmd_opts, &@stub_block)
      assert_equal 3, subject.instance_eval{ local_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, nil, @cmd_opts]
      spy_block = subject.instance_eval{ local_cmd_stub_blocks[exp_key] }
      assert_same @stub_block, spy_block

      subject.stub_cmd(@cmd_str, @cmd_input, @cmd_opts, &@stub_block)
      assert_equal 4, subject.instance_eval{ local_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, @cmd_input, @cmd_opts]
      spy_block = subject.instance_eval{ local_cmd_stub_blocks[exp_key] }
      assert_same @stub_block, spy_block
    end

    should "allow unstubbing cmds" do
      subject.stub_cmd(@cmd_str, &@stub_block)
      subject.stub_cmd(@cmd_str, @cmd_input, &@stub_block)
      subject.stub_cmd(@cmd_str, @cmd_opts, &@stub_block)
      subject.stub_cmd(@cmd_str, @cmd_input, @cmd_opts, &@stub_block)

      assert_equal 4, subject.instance_eval{ local_cmd_stub_blocks.size }

      subject.unstub_cmd(@cmd_str)
      assert_equal 3, subject.instance_eval{ local_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, nil, nil]
      spy_block = subject.instance_eval{ local_cmd_stub_blocks[exp_key] }
      assert_nil spy_block

      subject.unstub_cmd(@cmd_str, @cmd_input)
      assert_equal 2, subject.instance_eval{ local_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, @cmd_input, nil]
      spy_block = subject.instance_eval{ local_cmd_stub_blocks[exp_key] }
      assert_nil spy_block

      subject.unstub_cmd(@cmd_str, @cmd_opts)
      assert_equal 1, subject.instance_eval{ local_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, nil, @cmd_opts]
      spy_block = subject.instance_eval{ local_cmd_stub_blocks[exp_key] }
      assert_nil spy_block

      subject.unstub_cmd(@cmd_str, @cmd_input, @cmd_opts)
      assert_equal 0, subject.instance_eval{ local_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, @cmd_input, @cmd_opts]
      spy_block = subject.instance_eval{ local_cmd_stub_blocks[exp_key] }
      assert_nil spy_block
    end

    should "not error unstubbing cmds that aren't stubbed" do
      assert_nothing_raised{ subject.unstub_cmd(@cmd_str) }
      assert_nothing_raised{ subject.unstub_cmd(@cmd_str, @cmd_input) }
      assert_nothing_raised{ subject.unstub_cmd(@cmd_str, @cmd_opts) }
      assert_nothing_raised{ subject.unstub_cmd(@cmd_str, @cmd_input, @cmd_opts) }
    end

    should "allow unstubbing all cmds" do
      subject.stub_cmd(@cmd_str, &@stub_block)
      subject.stub_cmd(@cmd_str, @cmd_input, &@stub_block)
      subject.stub_cmd(@cmd_str, @cmd_opts, &@stub_block)
      subject.stub_cmd(@cmd_str, @cmd_input, @cmd_opts, &@stub_block)

      assert_equal 4, subject.instance_eval{ local_cmd_stub_blocks.size }
      subject.unstub_all_cmds
      assert_equal 0, subject.instance_eval{ local_cmd_stub_blocks.size }
    end

    should "know its local cmd stubs" do
      subject.stub_cmd(@cmd_str, &@stub_block)
      subject.stub_cmd(@cmd_str, @cmd_input, &@stub_block)
      subject.stub_cmd(@cmd_str, @cmd_opts, &@stub_block)
      subject.stub_cmd(@cmd_str, @cmd_input, @cmd_opts, &@stub_block)

      exp = Stub.new(@cmd_str, nil, nil, @stub_block)
      assert_includes exp, subject.local_cmd_stubs
      exp = Stub.new(@cmd_str, @cmd_input, nil, @stub_block)
      assert_includes exp, subject.local_cmd_stubs
      exp = Stub.new(@cmd_str, nil, @cmd_opts, @stub_block)
      assert_includes exp, subject.local_cmd_stubs
      exp = Stub.new(@cmd_str, @cmd_input, @cmd_opts, @stub_block)
      assert_includes exp, subject.local_cmd_stubs
    end

    should "allow stubbing ssh" do
      assert_equal 0, subject.instance_eval{ remote_cmd_stub_blocks.size }

      subject.stub_ssh(@cmd_str, &@stub_block)
      assert_equal 1, subject.instance_eval{ remote_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, nil, nil]
      spy_block = subject.instance_eval{ remote_cmd_stub_blocks[exp_key] }
      assert_same @stub_block, spy_block

      subject.stub_ssh(@cmd_str, @cmd_input, &@stub_block)
      assert_equal 2, subject.instance_eval{ remote_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, @cmd_input, nil]
      spy_block = subject.instance_eval{ remote_cmd_stub_blocks[exp_key] }
      assert_same @stub_block, spy_block

      subject.stub_ssh(@cmd_str, @given_ssh_opts, &@stub_block)
      assert_equal 3, subject.instance_eval{ remote_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, nil, @given_ssh_opts]
      spy_block = subject.instance_eval{ remote_cmd_stub_blocks[exp_key] }
      assert_same @stub_block, spy_block

      subject.stub_ssh(@cmd_str, @cmd_input, @given_ssh_opts, &@stub_block)
      assert_equal 4, subject.instance_eval{ remote_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, @cmd_input, @given_ssh_opts]
      spy_block = subject.instance_eval{ remote_cmd_stub_blocks[exp_key] }
      assert_same @stub_block, spy_block
    end

    should "allow unstubbing ssh" do
      subject.stub_ssh(@cmd_str, &@stub_block)
      subject.stub_ssh(@cmd_str, @cmd_input, &@stub_block)
      subject.stub_ssh(@cmd_str, @given_ssh_opts, &@stub_block)
      subject.stub_ssh(@cmd_str, @cmd_input, @given_ssh_opts, &@stub_block)

      assert_equal 4, subject.instance_eval{ remote_cmd_stub_blocks.size }

      subject.unstub_ssh(@cmd_str)
      assert_equal 3, subject.instance_eval{ remote_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, nil, nil]
      spy_block = subject.instance_eval{ remote_cmd_stub_blocks[exp_key] }
      assert_nil spy_block

      subject.unstub_ssh(@cmd_str, @cmd_input)
      assert_equal 2, subject.instance_eval{ remote_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, @cmd_input, nil]
      spy_block = subject.instance_eval{ remote_cmd_stub_blocks[exp_key] }
      assert_nil spy_block

      subject.unstub_ssh(@cmd_str, @given_ssh_opts)
      assert_equal 1, subject.instance_eval{ remote_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, nil, @given_ssh_opts]
      spy_block = subject.instance_eval{ remote_cmd_stub_blocks[exp_key] }
      assert_nil spy_block

      subject.unstub_ssh(@cmd_str, @cmd_input, @given_ssh_opts)
      assert_equal 0, subject.instance_eval{ remote_cmd_stub_blocks.size }
      exp_key   = [@cmd_str, @cmd_input, @given_ssh_opts]
      spy_block = subject.instance_eval{ remote_cmd_stub_blocks[exp_key] }
      assert_nil spy_block
    end

    should "not error unstubbing ssh that aren't stubbed" do
      assert_nothing_raised{ subject.unstub_ssh(@cmd_str) }
      assert_nothing_raised{ subject.unstub_ssh(@cmd_str, @cmd_input) }
      assert_nothing_raised{ subject.unstub_ssh(@cmd_str, @given_ssh_opts) }
      assert_nothing_raised{ subject.unstub_ssh(@cmd_str, @cmd_input, @given_ssh_opts) }
    end

    should "allow unstubbing all ssh" do
      subject.stub_ssh(@cmd_str, &@stub_block)
      subject.stub_ssh(@cmd_str, @cmd_input, &@stub_block)
      subject.stub_ssh(@cmd_str, @given_ssh_opts, &@stub_block)
      subject.stub_ssh(@cmd_str, @cmd_input, @given_ssh_opts, &@stub_block)

      assert_equal 4, subject.instance_eval{ remote_cmd_stub_blocks.size }
      subject.unstub_all_ssh
      assert_equal 0, subject.instance_eval{ remote_cmd_stub_blocks.size }
    end

    should "know its remote cmd stubs" do
      subject.stub_ssh(@cmd_str, &@stub_block)
      subject.stub_ssh(@cmd_str, @cmd_input, &@stub_block)
      subject.stub_ssh(@cmd_str, @given_ssh_opts, &@stub_block)
      subject.stub_ssh(@cmd_str, @cmd_input, @given_ssh_opts, &@stub_block)

      exp = Stub.new(@cmd_str, nil, nil, @stub_block)
      assert_includes exp, subject.remote_cmd_stubs
      exp = Stub.new(@cmd_str, @cmd_input, nil, @stub_block)
      assert_includes exp, subject.remote_cmd_stubs
      exp = Stub.new(@cmd_str, nil, @given_ssh_opts, @stub_block)
      assert_includes exp, subject.remote_cmd_stubs
      exp = Stub.new(@cmd_str, @cmd_input, @given_ssh_opts, @stub_block)
      assert_includes exp, subject.remote_cmd_stubs
    end

    # test the `Runner` interface that this overwrites, these are private
    # methods but since they overwrite the runner's interface we want to test
    # them as if they were public methods

    should "use stubs with `build_local_cmd`" do
      cmd_str, cmd_input, cmd_opts = @cmd_str, @cmd_input, @cmd_opts

      subject.stub_cmd(@cmd_str){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval{ build_local_cmd(cmd_str, nil, nil) }
      assert_false spy.success?

      subject.unstub_all_cmds
      subject.stub_cmd(@cmd_str, @cmd_input){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval{ build_local_cmd(cmd_str, cmd_input, nil) }
      assert_false spy.success?

      subject.unstub_all_cmds
      subject.stub_cmd(@cmd_str, @cmd_opts){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval{ build_local_cmd(cmd_str, nil, cmd_opts) }
      assert_false spy.success?

      subject.unstub_all_cmds
      subject.stub_cmd(@cmd_str, @cmd_input, @cmd_opts){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval{ build_local_cmd(cmd_str, cmd_input, cmd_opts) }
      assert_false spy.success?
    end

    should "cache stubbed local cmd spies using `build_local_cmd`" do
      subject.stub_cmd(@cmd_str, @cmd_input, @cmd_opts, &@stub_block)

      cmd_str, cmd_input, cmd_opts = @cmd_str, @cmd_input, @cmd_opts
      spy    = subject.instance_eval{ build_local_cmd(cmd_str, cmd_input, cmd_opts) }
      result = subject.instance_eval{ build_local_cmd(cmd_str, cmd_input, cmd_opts) }
      assert_same spy, result
    end

    should "remove cached stubbed local cmd spies when unstubbing" do
      subject.stub_cmd(@cmd_str, @cmd_input, @cmd_opts, &@stub_block)
      cmd_str, cmd_input, cmd_opts = @cmd_str, @cmd_input, @cmd_opts
      spy = subject.instance_eval{ build_local_cmd(cmd_str, cmd_input, cmd_opts) }

      subject.unstub_all_cmds
      result = subject.instance_eval{ build_local_cmd(cmd_str, cmd_input, cmd_opts) }
      assert_not_same spy, result
    end

    should "use stubs with `build_remote_cmd`" do
      cmd_str, cmd_input, given_opts, ssh_opts = @cmd_str, @cmd_input, @given_ssh_opts, @ssh_opts

      subject.stub_ssh(@cmd_str){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval{ build_remote_cmd(cmd_str, nil, nil, ssh_opts) }
      assert_false spy.success?

      subject.unstub_all_ssh
      subject.stub_ssh(@cmd_str, @cmd_input){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval do
        build_remote_cmd(cmd_str, cmd_input, nil, ssh_opts)
      end
      assert_false spy.success?

      subject.unstub_all_ssh
      subject.stub_ssh(@cmd_str, @given_ssh_opts){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval do
        build_remote_cmd(cmd_str, nil, given_opts, ssh_opts)
      end
      assert_false spy.success?

      subject.unstub_all_ssh
      subject.stub_ssh(@cmd_str, @cmd_input, @given_ssh_opts){ |s| s.exitstatus = 1 }
      spy = subject.instance_eval do
        build_remote_cmd(cmd_str, cmd_input, given_opts, ssh_opts)
      end
      assert_false spy.success?
    end

    should "cache stubbed remote cmd spies using `build_remote_cmd`" do
      subject.stub_ssh(@cmd_str, @cmd_input, @given_ssh_opts, &@stub_block)

      cmd_str, cmd_input, given_opts, ssh_opts = @cmd_str, @cmd_input, @given_ssh_opts, @ssh_opts
      spy = subject.instance_eval do
        build_remote_cmd(cmd_str, cmd_input, given_opts, ssh_opts)
      end
      result = subject.instance_eval do
        build_remote_cmd(cmd_str, cmd_input, given_opts, ssh_opts)
      end
      assert_same spy, result
    end

    should "remove cached stubbed ssh spies when unstubbing" do
      subject.stub_ssh(@cmd_str, @cmd_input, @given_ssh_opts, &@stub_block)
      cmd_str, cmd_input, given_opts, ssh_opts = @cmd_str, @cmd_input, @given_ssh_opts, @ssh_opts
      spy = subject.instance_eval do
        build_remote_cmd(cmd_str, cmd_input, given_opts, ssh_opts)
      end

      subject.unstub_all_ssh
      result = subject.instance_eval do
        build_remote_cmd(cmd_str, cmd_input, given_opts, ssh_opts)
      end
      assert_not_same spy, result
    end

    should "defer to `has_the_stubs_build_remote_cmd` when cmd isn't stubbed" do
      cmd_str, cmd_input, given_opts, ssh_opts = @cmd_str, @cmd_input, @given_ssh_opts, @ssh_opts
      result = subject.instance_eval do
        build_remote_cmd(cmd_str, cmd_input, given_opts, ssh_opts)
      end
      assert_equal BuiltCmd.new(cmd_str, ssh_opts), result
    end

  end

  BuiltCmd = Struct.new(:cmd_str, :opts)

end

