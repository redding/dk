require 'dk/stringify_params'

module Dk

  class Config

    attr_reader :init_procs, :params

    def initialize
      @init_procs = []
      @params     = {}
    end

    def init
      self.init_procs.each{ |block| self.instance_eval(&block) }
    end

    def set_param(key, value)
      self.params.merge!(dk_normalize_params(key => value))
    end

    private

    def dk_normalize_params(params)
      StringifyParams.new(params)
    end

  end

end
