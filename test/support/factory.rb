require 'assert/factory'

module Factory
  extend Assert::Factory

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
