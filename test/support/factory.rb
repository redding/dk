require 'assert/factory'

module Factory
  extend Assert::Factory

  def self.ssh_cmd_opts
    cmd_opts = { Factory.string => Factory.string }
    # optionally have these options, this will ensure the default ssh cmd opts
    # are used if these aren't provided
    if Factory.boolean
      cmd_opts.merge!({
        :hosts         => Factory.hosts,
        :ssh_args      => Factory.string,
        :host_ssh_args => { Factory.string => Factory.string }
      })
    end
    cmd_opts
  end

  def self.stdout
    Factory.integer(3).times.map{ Factory.string }.join("\n")
  end

  def self.stderr
    Factory.integer(3).times.map{ Factory.string }.join("\n")
  end

  def self.exitstatus
    [0, 1].sample
  end

  def self.hosts
    Factory.integer(3).times.map{ "#{Factory.string}.example.com" }
  end

  def self.log_file
    ROOT_PATH.join("test/support/log/#{Factory.string}.txt")
  end

  def self.task_callback(task_class, params = nil)
    Dk::Task::Callback.new(task_class, params || {})
  end

end
