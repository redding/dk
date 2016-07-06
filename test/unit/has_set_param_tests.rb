require 'assert'
require 'dk/has_set_param'

require 'much-plugin'

module Dk::HasSetParam

  class UnitTests < Assert::Context
    desc "Dk::HasSetParam"
    setup do
      @mixin_class = Dk::HasSetParam

      @params_class = Class.new do
        include Dk::HasSetParam
        attr_reader :params
        def initialize; @params = {}; end
      end
    end
    subject{ @params_class }

    should "use much-plugin" do
      assert_includes MuchPlugin, subject
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @params = @params_class.new
    end
    subject{ @params }

    should have_imeths :set_param

    should "stringify and set param values with `set_param`" do
      key, value = Factory.string.to_sym, Factory.string
      subject.set_param(key, value)

      assert_equal value, subject.params[key.to_s]
      assert_nil subject.params[key]
    end

  end

end
