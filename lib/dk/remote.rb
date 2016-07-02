require 'dk/local'

module Dk; end
module Dk::Remote

  class BaseCmd

    attr_reader :hosts, :cmd_str, :local_cmds

    def initialize(local_cmd_or_spy_klass, cmd_str, opts)
      opts   ||= {}
      @hosts   = (opts[:hosts] || []).sort # TODO: accept ssh opts string
      @cmd_str = cmd_str

      @local_cmds = @hosts.inject({}) do |cmds, host|
        # TODO: build host-specific ssh cmd str
        cmds[host] = local_cmd_or_spy_klass.new(cmd_str, :env => opts[:env])
        cmds
      end
    end

    def to_s; self.cmd_str; end

    def run(input = nil)
      self.hosts.each{ |host| @local_cmds[host].scmd.start(input) }
      self.hosts.each{ |host| @local_cmds[host].scmd.wait }
      self
    end

    def success?
      self.hosts.inject(true) do |success, host|
        success && @local_cmds[host].success?
      end
    end

    def output_lines
      self.hosts.inject([]) do |lines, host|
        lines + @local_cmds[host].output_lines
      end
    end

  end

  class Cmd < BaseCmd

    def initialize(cmd_str, opts = nil)
      super(Dk::Local::Cmd, cmd_str, opts)
    end

  end

  class CmdSpy < BaseCmd

    attr_reader :cmd_opts

    def initialize(cmd_str, opts = nil)
      super(Dk::Local::CmdSpy, cmd_str, opts)
      @cmd_opts = opts
      @first_local_cmd_spy = @local_cmds[@hosts.first]
    end

    # just set the first local cmd, this will have an overall effect
    def stdout=(value);     @first_local_cmd_spy.stdout     = value; end
    def stderr=(value);     @first_local_cmd_spy.stderr     = value; end
    def exitstatus=(value); @first_local_cmd_spy.exitstatus = value; end

    # just query the firs tlocal cmd - if run for one it was run for all
    def run_calls;   @first_local_cmd_spy.scmd.start_calls;   end
    def run_called?; @first_local_cmd_spy.scmd.start_called?; end

  end

end
