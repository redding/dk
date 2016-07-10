require 'much-plugin'

module Dk

  module HasSSHOpts
    include MuchPlugin

    plugin_included do
      include InstanceMethods

    end

    module InstanceMethods

      def ssh_hosts(group_name = nil, *values)
        return @ssh_hosts if group_name.nil?
        @ssh_hosts[group_name.to_s] = values.flatten if !values.empty?
        @ssh_hosts[group_name.to_s]
      end

      def ssh_args(value = nil)
        @ssh_args = value if !value.nil?
        @ssh_args
      end

      def host_ssh_args(host_name = nil, value = nil)
        return @host_ssh_args if host_name.nil?
        @host_ssh_args[host_name.to_s] = value if !value.nil?
        @host_ssh_args[host_name.to_s]
      end

    end

  end

end
