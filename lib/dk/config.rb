require 'dk/has_set_param'

module Dk

  class Config
    include Dk::HasSetParam

    attr_reader :init_procs, :params

    def initialize
      @init_procs = []
      @params     = {}
    end

    def init
      self.init_procs.each{ |block| self.instance_eval(&block) }
    end

  end

end
