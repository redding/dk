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

end
