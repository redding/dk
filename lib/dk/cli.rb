require 'dk'
require 'dk/dk_runner'
require 'dk/dry_runner'
require 'dk/tree_runner'
require 'dk/version'

module Dk

  class CLI

    DEFAULT_CONFIG_PATH = 'config/dk.rb'.freeze

    def self.run(args)
      self.new.run(*args)
    end

    attr_reader :clirb

    def initialize(kernel = nil)
      @kernel = kernel || Kernel

      load config_path
      Dk.init
      @config = Dk.config

      @clirb = CLIRB.new do
        option 'list-tasks', 'list all tasks available to run', {
          :abbrev => 'T'
        }
        option 'dry-run', 'run the tasks without executing any local/remote cmds'
        option 'tree',    'print out the tree of tasks/sub-tasks that would be run'
        option 'verbose', 'run tasks showing verbose (ie debug log level) details'
      end
    end

    def run(*args)
      begin
        run!(*args)
      rescue ShowTaskList
        @kernel.puts task_list
      rescue CLIRB::HelpExit
        @kernel.puts help
      rescue CLIRB::VersionExit
        @kernel.puts Dk::VERSION
      rescue CLIRB::Error, Dk::Config::UnknownTaskError => exception
        @kernel.puts help
        @kernel.puts "\n\n#{exception.message}\n"
        @kernel.exit 1
      rescue Dk::NoticeError => exception
        @kernel.puts "\n\n#{exception.message}\n\n"
        @kernel.puts exception.backtrace.first
        @kernel.exit 1
      rescue StandardError => exception
        @kernel.puts "\n\n#{exception.class}: #{exception.message}"
        @kernel.puts exception.backtrace.join("\n")
        @kernel.exit 1
      end
      @kernel.exit 0
    end

    private

    def run!(*args)
      @clirb.parse!(args)
      raise ShowTaskList if @clirb.opts['list-tasks']

      @config.stdout_log_level('debug') if @clirb.opts['verbose']

      unknowns = @clirb.args.select{ |name| !@config.tasks.keys.include?(name) }
      if !unknowns.empty?
        raise Dk::Config::UnknownTaskError, unknowns.map{ |u| "`#{u}`"}.join(', ')
      end

      runner = get_runner(@config, @clirb.opts)
      runner.log_cli_run(args.join(' ')) do
        @clirb.args.each do |task_name|
          runner.log_cli_task_run(task_name) do
            runner.run(@config.task(task_name))
          end
        end
      end
    end

    def help
      "Usage: dk [TASKS] [options]\n\n" \
      "Tasks:\n" \
      "#{task_list('    ')}\n\n" \
      "Options: #{@clirb}"
    end

    def task_list(prefix = '')
      max_name_width = @config.tasks.keys.map(&:size).max
      items = @config.tasks.map do |(name, task_class)|
        "#{prefix}#{name.ljust(max_name_width)} # #{task_class.description}"
      end
      items.sort.join("\n")
    end

    def config_path
      File.expand_path(ENV['DK_CONFIG'] || DEFAULT_CONFIG_PATH, ENV['PWD'])
    end

    def get_runner(config, opts)
      return Dk::DryRunner.new(config) if opts['dry-run']

      if opts['tree']
        @kernel.puts "building task tree#{'s' if @clirb.args.size > 1}..."
        return Dk::TreeRunner.new(config, @kernel)
      end

      Dk::DkRunner.new(config)
    end

    ShowTaskList = Class.new(RuntimeError)

  end

  class CLIRB  # Version 1.0.0, https://github.com/redding/cli.rb
    Error    = Class.new(RuntimeError);
    HelpExit = Class.new(RuntimeError); VersionExit = Class.new(RuntimeError)
    attr_reader :argv, :args, :opts, :data

    def initialize(&block)
      @options = []; instance_eval(&block) if block
      require 'optparse'
      @data, @args, @opts = [], [], {}; @parser = OptionParser.new do |p|
        p.banner = ''; @options.each do |o|
          @opts[o.name] = o.value; p.on(*o.parser_args){ |v| @opts[o.name] = v }
        end
        p.on_tail('--version', ''){ |v| raise VersionExit, v.to_s }
        p.on_tail('--help',    ''){ |v| raise HelpExit,    v.to_s }
      end
    end

    def option(*args); @options << Option.new(*args); end
    def parse!(argv)
      @args = (argv || []).dup.tap do |args_list|
        begin; @parser.parse!(args_list)
        rescue OptionParser::ParseError => err; raise Error, err.message; end
      end; @data = @args + [@opts]
    end
    def to_s; @parser.to_s; end
    def inspect
      "#<#{self.class}:#{'0x0%x' % (object_id << 1)} @data=#{@data.inspect}>"
    end

    class Option
      attr_reader :name, :opt_name, :desc, :abbrev, :value, :klass, :parser_args

      def initialize(name, *args)
        settings, @desc = args.last.kind_of?(::Hash) ? args.pop : {}, args.pop || ''
        @name, @opt_name, @abbrev = parse_name_values(name, settings[:abbrev])
        @value, @klass = gvalinfo(settings[:value])
        @parser_args = if [TrueClass, FalseClass, NilClass].include?(@klass)
          ["-#{@abbrev}", "--[no-]#{@opt_name}", @desc]
        else
          ["-#{@abbrev}", "--#{@opt_name} #{@opt_name.upcase}", @klass, @desc]
        end
      end

      private

      def parse_name_values(name, custom_abbrev)
        [ (processed_name = name.to_s.strip.downcase), processed_name.gsub('_', '-'),
          custom_abbrev || processed_name.gsub(/[^a-z]/, '').chars.first || 'a'
        ]
      end
      def gvalinfo(v); v.kind_of?(Class) ? [nil,gklass(v)] : [v,gklass(v.class)]; end
      def gklass(k); k == Fixnum ? Integer : k; end
    end
  end

end
