require 'dk/config'
require 'dk/local'

module Dk; end
module Dk::Remote

  def self.ssh_cmd_str(cmd_str, host, args, host_args)
    host_args = host_args[host.to_s] if !host.nil?
    val = "\"#{cmd_str.gsub(/\s+/, ' ')}\"".gsub("\\", "\\\\\\").gsub('"', '\"')
    "ssh #{args} #{host_args} #{host} -- \"sh -c #{val}\""
  end

  class BaseCmd

    attr_reader :hosts, :ssh_args, :host_ssh_args, :cmd_str, :local_cmds

    def initialize(local_cmd_or_spy_klass, cmd_str, opts)
      opts ||= {}
      if nil_or_empty_or_missing_hosts(opts[:hosts])
        raise NoHostsError, "no hosts to run cmd on (#{opts[:hosts].inspect})"
      end

      @hosts         = opts[:hosts].sort
      @ssh_args      = opts[:ssh_args]      || Dk::Config::DEFAULT_SSH_ARGS.dup
      @host_ssh_args = opts[:host_ssh_args] || Dk::Config::DEFAULT_HOST_SSH_ARGS.dup
      @cmd_str       = cmd_str

      @local_cmds = @hosts.inject({}) do |cmds, host|
        cmds[host] = local_cmd_or_spy_klass.new(
          ssh_cmd_str(@cmd_str, host, @ssh_args, @host_ssh_args),
          { :env => opts[:env] }
        )
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
        lines + build_output_lines(host, @local_cmds[host].output_lines)
      end
    end

    private

    def nil_or_empty_or_missing_hosts(h)
      h.nil? ||
      !h.respond_to?(:empty?) || h.empty? ||
      !h.respond_to?(:select) || h.select(&:nil?).size > 0
    end

    # escape everything properly; run in sh to ensure full profile is loaded
    def ssh_cmd_str(cmd_str, host, args, host_args)
      Dk::Remote.ssh_cmd_str(cmd_str, host, args, host_args)
    end

    def build_output_lines(host, local_cmd_output_lines)
      local_cmd_output_lines.map{ |ol| OutputLine.new(host, ol.name, ol.line) }
    end

    OutputLine = Struct.new(:host, :name, :line)

  end

  NoHostsError = Class.new(ArgumentError)

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

    def run_input
      return nil unless self.run_called?
      self.run_calls.first.input
    end

    # just set the first local cmd, this will have an overall effect
    def stdout=(value);     @first_local_cmd_spy.stdout     = value; end
    def stderr=(value);     @first_local_cmd_spy.stderr     = value; end
    def exitstatus=(value); @first_local_cmd_spy.exitstatus = value; end

    # just query the firs tlocal cmd - if run for one it was run for all
    def run_calls;   @first_local_cmd_spy.scmd.start_calls;   end
    def run_called?; @first_local_cmd_spy.scmd.start_called?; end

    def ssh?; true; end

  end

end
