require 'dk/runner'

module Dk

  class ConfigRunner < Runner

    def initialize(config, opts = nil)
      opts ||= {}
      super({
        :params                   => config.params,
        :before_callbacks         => config.before_callbacks,
        :prepend_before_callbacks => config.prepend_before_callbacks,
        :after_callbacks          => config.after_callbacks,
        :prepend_after_callbacks  => config.prepend_after_callbacks,
        :ssh_hosts                => config.ssh_hosts,
        :ssh_args                 => config.ssh_args,
        :host_ssh_args            => config.host_ssh_args,
        :logger                   => opts[:logger] || config.dk_logger
      })
    end

  end

end
