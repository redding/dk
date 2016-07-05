require 'assert'
require 'dk'

require 'dk/config'

module Dk

  class UnitTests < Assert::Context
    desc "Dk"
    setup do
      @dk_module = Dk
    end
    subject{ @dk_module }

    should have_imeths :config, :configure, :init

    should "know its config" do
      assert_instance_of Config, subject.config
    end

    should "add init procs to its config on `configure`" do
      assert_equal [], subject.config.init_procs

      init_block = proc{}
      subject.configure(&init_block)

      assert_equal [init_block], subject.config.init_procs
    end

    should "instance eval its init procs on init" do
      config_init_called = false
      Assert.stub(subject.config, :init){ config_init_called = true }

      subject.init
      assert_true config_init_called
    end

  end

end
