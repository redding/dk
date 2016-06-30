require 'scmd'

module Dk; end
module Dk::Local

  class BaseCmd

    def initialize(scmd_or_spy)
      @scmd = scmd_or_spy
    end

    def cmd_str; @scmd.cmd_str; end

    def run(input = nil);  @scmd.run(input);  self; end
    def run!(input = nil); @scmd.run!(input); self; end

    def stdout;   @scmd.stdout;   end
    def stderr;   @scmd.stderr;   end
    def success?; @scmd.success?; end
    def to_s;     @scmd.to_s;     end

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
      opts ||= {}
      super(Scmd.new(cmd_str, :env => opts[:env]))
    end

  end

  class CmdSpy < BaseCmd

    attr_reader :cmd_opts

    def initialize(cmd_str, opts = nil)
      require 'scmd/command_spy'
      super(Scmd::CommandSpy.new(cmd_str, opts))
      @cmd_opts = opts
    end

    def stdout=(value);     @scmd.stdout     = value; end
    def stderr=(value);     @scmd.stderr     = value; end
    def exitstatus=(value); @scmd.exitstatus = value; end

    def run_calls;        @scmd.run_calls;        end
    def run_bang_calls;   @scmd.run_bang_calls;   end
    def run_called?;      @scmd.run_called?;      end
    def run_bang_called?; @scmd.run_bang_called?; end

  end

end
