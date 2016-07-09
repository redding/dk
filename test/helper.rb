# this file is automatically required when you run `assert`
# put any test helpers here

# add the root dir to the load path
require 'pathname'
ROOT_PATH = Pathname.new(File.expand_path("../..", __FILE__))
$LOAD_PATH.unshift(ROOT_PATH)

# require pry for debugging (`binding.pry`)
require 'pry'

require 'test/support/factory'

# put scmd in test mode
ENV['SCMD_TEST_MODE'] = '1'

# 1.8.7 backfills

# Array#sample
if !(a = Array.new).respond_to?(:sample) && a.respond_to?(:choice)
  class Array
    alias_method :sample, :choice
  end
end
