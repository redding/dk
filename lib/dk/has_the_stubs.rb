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

      def local_cmd_stubs
        @local_cmd_stubs ||= []
      end

      def stub_cmd(cmd_str, args = nil, &block)
        args ||= {}

        cmd_str_proc    = get_cmd_ssh_proc(cmd_str)
        input_proc      = get_cmd_ssh_proc(args[:input])
        given_opts_proc = get_cmd_ssh_proc(args[:opts])

        local_cmd_stubs.unshift(
          Stub.new(cmd_str_proc, input_proc, given_opts_proc, block)
        )
      end

      def unstub_all_cmds
        local_cmd_stubs.clear
      end

      # ssh stub API

      def remote_cmd_stubs
        @remote_cmd_stubs ||= []
      end

      def stub_ssh(cmd_str, args = nil, &block)
        args ||= {}

        cmd_str_proc    = get_cmd_ssh_proc(cmd_str)
        input_proc      = get_cmd_ssh_proc(args[:input])
        given_opts_proc = get_cmd_ssh_proc(args[:opts])

        remote_cmd_stubs.unshift(
          Stub.new(cmd_str_proc, input_proc, given_opts_proc, block)
        )
      end

      def unstub_all_ssh
        remote_cmd_stubs.clear
      end

      private

      def get_cmd_ssh_proc(obj)
        obj.kind_of?(::Proc) ? obj : proc{ obj }
      end

      def find_cmd_ssh_stub_block(stubs, task, cmd_str, input, given_opts)
        stub = stubs.find do |stub|
          task.instance_eval(&stub.cmd_str_proc)    == cmd_str    &&
          task.instance_eval(&stub.input_proc)      == input      &&
          task.instance_eval(&stub.given_opts_proc) == given_opts
        end
        stub ? stub.block : nil
      end

      # if the cmd is stubbed, build a spy and apply the stub (or return the
      # cached spy), otherwise let the runner decide how to handle the local
      # cmd
      def build_local_cmd(task, cmd_str, input, given_opts)
        b = find_cmd_ssh_stub_block(local_cmd_stubs, task, cmd_str, input, given_opts)
        if b
          Local::CmdSpy.new(cmd_str, given_opts).tap(&b)
        else
          has_the_stubs_build_local_cmd(cmd_str, given_opts)
        end
      end

      def has_the_stubs_build_local_cmd(cmd_str, given_opts)
        raise NotImplementedError
      end

      # if the cmd is stubbed, build a spy and apply the stub (or return the
      # cached spy), otherwise let the runner decide how to handle the remote
      # cmd; when building the spy use the ssh opts, this allows stubbing and
      # calling ssh cmds with the same opts but also allows building a valid
      # remote cmd that has an ssh host
      def build_remote_cmd(task, cmd_str, input, given_opts, ssh_opts)
        b = find_cmd_ssh_stub_block(remote_cmd_stubs, task, cmd_str, input, given_opts)
        if b
          Remote::CmdSpy.new(cmd_str, ssh_opts).tap(&b)
        else
          has_the_stubs_build_remote_cmd(cmd_str, ssh_opts)
        end
      end

      def has_the_stubs_build_remote_cmd(cmd_str, ssh_opts)
        raise NotImplementedError
      end

    end

    Stub = Struct.new(:cmd_str_proc, :input_proc, :given_opts_proc, :block)

  end

end
