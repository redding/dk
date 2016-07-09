require 'dk/runner'

module Dk

  class ConfigRunner < Runner

    def initialize(config, opts = nil)
      opts ||= {}
      super({
        :params        => config.params,
        :ssh_hosts     => config.ssh_hosts,
        :ssh_args      => config.ssh_args,
        :host_ssh_args => config.host_ssh_args,
        :logger        => opts[:logger] || config.dk_logger
      })
    end

  end

end
