require 'scmd'

module Dk; end
module Dk::Local

  class BaseCmd

    attr_reader :scmd, :cmd_str

    def initialize(scmd_or_spy_klass, cmd_str, opts)
      opts ||= {}

      @cmd_str = cmd_str
      @scmd    = scmd_or_spy_klass.new(@cmd_str, :env => opts[:env])
    end

    def to_s; self.cmd_str; end

    def run(input = nil)
      @scmd.run(input)
      self
    end

    def stdout;   @scmd.stdout;   end
    def stderr;   @scmd.stderr;   end
    def success?; @scmd.success?; end

    def output_lines
      build_stdout_lines(self.stdout) + build_stderr_lines(self.stderr)
    end

    private

    def build_stdout_lines(stdout)
      build_output_lines('stdout', stdout)
    end

    def build_stderr_lines(stderr)
      build_output_lines('stderr', stderr)
    end

    def build_output_lines(name, output)
      output.to_s.strip.split("\n").map{ |line| OutputLine.new(name, line) }
    end

    OutputLine = Struct.new(:name, :line)

  end

  class Cmd < BaseCmd

    def initialize(cmd_str, opts = nil)
      super(Scmd, cmd_str, opts)
    end

  end

  class CmdSpy < BaseCmd

    attr_reader :cmd_opts

    def initialize(cmd_str, opts = nil)
      require 'scmd/command_spy'
      super(Scmd::CommandSpy, cmd_str, opts)
      @cmd_opts = opts
    end

    def run_input
      return nil unless self.run_called?
      self.run_calls.first.input
    end

    def stdout=(value);     @scmd.stdout     = value; end
    def stderr=(value);     @scmd.stderr     = value; end
    def exitstatus=(value); @scmd.exitstatus = value; end

    def run_calls;   @scmd.run_calls;   end
    def run_called?; @scmd.run_called?; end

    def ssh?; false; end

  end

end
