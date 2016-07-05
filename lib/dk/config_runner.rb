require 'dk/runner'

module Dk

  class ConfigRunner < Runner

    def initialize(config)
      super({}) # TODO: set runner args based on the config
    end

  end

end
