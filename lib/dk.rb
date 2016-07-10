require 'dk/version'
require 'dk/config'
require 'dk/task'

module Dk

  def self.config
    @config ||= Config.new
  end

  def self.configure(&block)
    self.config.init_procs << block
  end

  def self.init
    self.config.init
  end

  def self.reset
    @config = Config.new
  end

end
