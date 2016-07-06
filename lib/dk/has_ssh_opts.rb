require 'much-plugin'

module Dk

  module HasSSHOpts
    include MuchPlugin

    plugin_included do
      include InstanceMethods

    end

    module InstanceMethods

      def ssh_hosts(group_name = nil, value = nil)
        return @ssh_hosts if group_name.nil?
        @ssh_hosts[group_name.to_s] = value if !value.nil?
        @ssh_hosts[group_name.to_s]
      end

      def ssh_args(value = nil)
        @ssh_args = value if !value.nil?
        @ssh_args
      end

    end

  end

end
