require 'dk'
require 'test/support/config/task_defs'

Dk.configure do
  task 'cli-test-task',  CLITestTask
  task 'cli-other-task', CLIOtherTask
end
