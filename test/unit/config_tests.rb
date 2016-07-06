require 'assert'
require 'dk/config'

class Dk::Config

  class UnitTests < Assert::Context
    desc "Dk::Config"
    setup do
      @config_class = Dk::Config
    end
    subject{ @config_class }

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @config = @config_class.new
    end
    subject{ @config }

    should have_readers :init_procs, :params
    should have_imeths :init, :set_param

    should "default its attrs" do
      assert_equal [], subject.init_procs

      exp = {}
      assert_equal exp, subject.params
    end

    should "instance eval its init procs on init" do
      init_self = nil
      subject.init_procs << proc{ init_self = self }

      subject.init
      assert_equal @config, init_self
    end

    should "stringify and set param values with `set_param`" do
      key, value = Factory.string.to_sym, Factory.string
      subject.set_param(key, value)

      assert_equal value, subject.params[key.to_s]
      assert_nil subject.params[key]
    end

  end

end
