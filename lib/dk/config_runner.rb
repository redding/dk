require 'dk/runner'

module Dk

  class ConfigRunner < Runner

    def initialize(config)
      super({
        :params => config.params
      })
    end

  end

end
