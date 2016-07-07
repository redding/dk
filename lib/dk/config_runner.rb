require 'dk/runner'

module Dk

  class ConfigRunner < Runner

    def initialize(config)
      super({
        :params    => config.params,
        :ssh_hosts => config.ssh_hosts,
        :ssh_args  => config.ssh_args
      })
    end

  end

end
