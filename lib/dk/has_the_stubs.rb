require 'much-plugin'
require 'dk/local'
require 'dk/remote'

module Dk

  module HasTheStubs
    include MuchPlugin

    plugin_included do
      include InstanceMethods

    end

    module InstanceMethods

      # cmd stub api

      def stub_cmd(cmd_str, *args, &block)
        given_opts = args.last.kind_of?(::Hash) ? args.pop : nil
        input      = args.last

        key = has_the_stubs_cmd_key(cmd_str, input, given_opts)
        local_cmd_stub_blocks[key] = block
      end

      def unstub_cmd(cmd_str, *args)
        given_opts = args.last.kind_of?(::Hash) ? args.pop : nil
        input      = args.last

        key = has_the_stubs_cmd_key(cmd_str, input, given_opts)
        local_cmd_stub_blocks.delete(key)
        local_cmd_spies.delete(key)
      end

      def unstub_all_cmds
        local_cmd_stub_blocks.clear
        local_cmd_spies.clear
      end

      def local_cmd_stubs
        local_cmd_stub_blocks.map{ |key, block| Stub.new(*(key + [block])) }
      end

      # ssh stub API

      def stub_ssh(cmd_str, *args, &block)
        given_opts = args.last.kind_of?(::Hash) ? args.pop : nil
        input      = args.last

        key = has_the_stubs_cmd_key(cmd_str, input, given_opts)
        remote_cmd_stub_blocks[key] = block
      end

      def unstub_ssh(cmd_str, *args)
        given_opts = args.last.kind_of?(::Hash) ? args.pop : nil
        input      = args.last

        key = has_the_stubs_cmd_key(cmd_str, input, given_opts)
        remote_cmd_stub_blocks.delete(key)
        remote_cmd_spies.delete(key)
      end

      def unstub_all_ssh
        remote_cmd_stub_blocks.clear
        remote_cmd_spies.clear
      end

      def remote_cmd_stubs
        remote_cmd_stub_blocks.map{ |key, block| Stub.new(*(key + [block])) }
      end

      private

      # if the cmd is stubbed, build a spy and apply the stub (or return the
      # cached spy), otherwise let the runner decide how to handle the local
      # cmd
      def build_local_cmd(cmd_str, input, given_opts)
        key = has_the_stubs_cmd_key(cmd_str, input, given_opts)
        if (block = local_cmd_stub_blocks[key])
          local_cmd_spies[key] ||= Local::CmdSpy.new(cmd_str, given_opts).tap(&block)
        else
          has_the_stubs_build_local_cmd(cmd_str, given_opts)
        end
      end

      def has_the_stubs_build_local_cmd(cmd_str, given_opts)
        raise NotImplementedError
      end

      def local_cmd_stub_blocks; @local_cmd_stub_blocks ||= {}; end
      def local_cmd_spies;       @local_cmd_spies       ||= {}; end

      # if the cmd is stubbed, build a spy and apply the stub (or return the
      # cached spy), otherwise let the runner decide how to handle the remote
      # cmd; when building the spy use the ssh opts, this allows stubbing and
      # calling ssh cmds with the same opts but also allows building a valid
      # remote cmd that has an ssh host
      def build_remote_cmd(cmd_str, input, given_opts, ssh_opts)
        key = has_the_stubs_cmd_key(cmd_str, input, given_opts)
        if (block = remote_cmd_stub_blocks[key])
          remote_cmd_spies[key] ||= Remote::CmdSpy.new(cmd_str, ssh_opts).tap(&block)
        else
          has_the_stubs_build_remote_cmd(cmd_str, ssh_opts)
        end
      end

      def has_the_stubs_build_remote_cmd(cmd_str, ssh_opts)
        raise NotImplementedError
      end

      def remote_cmd_stub_blocks; @remote_cmd_stub_blocks ||= {}; end
      def remote_cmd_spies;       @remote_cmd_spies       ||= {}; end

      def has_the_stubs_cmd_key(cmd_str, input, given_opts)
        [cmd_str, input, given_opts]
      end

    end

    Stub = Struct.new(:cmd_str, :input, :given_opts, :block)

  end

end
