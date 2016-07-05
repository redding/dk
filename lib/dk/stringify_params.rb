module Dk

  module StringifyParams

    def self.new(object)
      case(object)
      when ::Hash
        object.inject({}){ |h, (k, v)| h.merge(k.to_s => self.new(v)) }
      when ::Array
        object.map{ |item| self.new(item) }
      else
        object
      end
    end

  end

end
