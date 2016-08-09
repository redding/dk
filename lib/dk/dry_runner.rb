require 'dk/config_runner'
require 'dk/has_the_stubs'

module Dk

  class DryRunner < ConfigRunner
    include HasTheStubs

    # run with disabled cmds, just log actions, but run all sub-tasks

    def initialize(config, *args)
      super(config, *args)
      config.dry_tree_cmd_stubs.each do |s|
        self.stub_cmd(s.cmd_str, s.input, s.given_opts, &s.block)
      end
      config.dry_tree_ssh_stubs.each do |s|
        self.stub_ssh(s.cmd_str, s.input, s.given_opts, &s.block)
      end
    end

    private

    def has_the_stubs_build_local_cmd(cmd_str, given_opts)
      given_opts ||= {}
      cmd_klass = given_opts[:dry_tree_run] ? Local::Cmd : Local::CmdSpy
      cmd_klass.new(cmd_str, given_opts)
    end

    def has_the_stubs_build_remote_cmd(cmd_str, ssh_opts)
      ssh_opts ||= {}
      cmd_klass = ssh_opts[:dry_tree_run] ? Remote::Cmd : Remote::CmdSpy
      cmd_klass.new(cmd_str, ssh_opts)
    end

  end

end
