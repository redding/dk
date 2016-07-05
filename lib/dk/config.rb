module Dk

  class Config

    attr_reader :init_procs

    def initialize
      @init_procs = []
    end

    def init
      self.init_procs.each{ |block| self.instance_eval(&block) }
    end

  end

end
