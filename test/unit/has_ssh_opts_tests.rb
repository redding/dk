require 'assert'
require 'dk/has_ssh_opts'

require 'much-plugin'

module Dk::HasSSHOpts

  class UnitTests < Assert::Context
    desc "Dk::HasSSHOpts"
    setup do
      @mixin_class = Dk::HasSSHOpts

      @opts_class = Class.new do
        include Dk::HasSSHOpts
        def initialize
          @ssh_hosts = {}
          @ssh_args  = ''
        end
      end
    end
    subject{ @opts_class }

    should "use much-plugin" do
      assert_includes MuchPlugin, subject
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @opts = @opts_class.new
    end
    subject{ @opts }

    should have_imeths :ssh_hosts, :ssh_args

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
