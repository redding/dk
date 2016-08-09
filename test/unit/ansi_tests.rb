require 'assert'
require 'dk/ansi'

module Dk::Ansi

  class UnitTests < Assert::Context
    desc "Dk::Ansi"
    subject{ Dk::Ansi }

    should have_imeths :styled_msg, :code_for

    should "know its codes" do
      assert_not_empty subject::CODES
    end

    should "map its code style names to ansi code strings" do
      styles = Factory.integer(3).times.map{ subject::CODES.keys.sample }
      exp = styles.map{ |n| "\e[#{subject::CODES[n]}m" }.join('')
      assert_equal exp, subject.code_for(*styles)

      styles = Factory.integer(3).times.map{ Factory.string }
      assert_equal '', subject.code_for(*styles)

      styles = []
      assert_equal '', subject.code_for(*styles)
    end

    should "know how to build ansi styled messages" do
      msg = Factory.string
      assert_equal msg, subject.styled_msg(msg)

      styles   = Factory.integer(3).times.map{ subject::CODES.keys.sample }
      exp_code = subject.code_for(*styles)
      exp      = exp_code + msg + subject.code_for(:reset)
      assert_equal exp, subject.styled_msg(msg, *styles)
    end

  end

end
