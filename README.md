# Dk

"Why'd you name this repo dk?" "Don't know"

This is some automated task runner thingy ala cap/rake (except without all the drama, breaking changes and difficult-to-test-ness).  You define tasks using classes; these tasks do stuff (maybe run some local or remote system commands?); you write tests for these tasks; you run them with a CLI.

## Usage

First define a task:

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  def run!
    log_info "this task does something"

    # ... do something ...
  end

end
```

Now route this task with a name so it can be run from the CLI:

TODO: router example

Now run this task using the CLI:

TODO: CLI example

### CLI

TODO

### Config

TODO

### Task

#### Helper Methods

The `Dk::Task` mixin provides a bunch of helper methods to make writing tasks easier and for commonizing common functions.

##### `params`, `set_param`

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  def run!
    params['some_param'] #=> "some value"

    set_param('some_other_param', 'some other value')
    params['some_other_param'] #=> "some other value"
  end

end
```

Use the `param` helper to access named params that the task was run with.  Params can be two ways: globally from the main config or from callback definitions and `run_task` calls.

Use the `set_param` method to set new global param values like you would on the main config.  Any subsequent tasks that are run will have this param value available to them.

##### `ssh_hosts`

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  def run!
    ssh_hosts('my-app-servers') # => nil

    ssh_hosts('my-app-servers', ['myserver1.example.com'])
    ssh_hosts('my-app-servers') # => ['myserver1.example.com']
  end

end
```

Use the `ssh_hosts` method to set new ssh host lists values like you would on the main config.  Any subsequent tasks that are run will have these ssh hosts available to their `ssh` commands.

##### `run_task`

```ruby
require 'dk/task'
require 'my_other_task'

class MyTask
  include Dk::Task

  def run!
    # ... do something before ...

    run_task MyOtherTask, :some => 'param value'

    # ... do something after ...
  end

end
```

Use the `run_task` helper to run other tasks.  This method takes an optional set of param values.  Any params given will be merged onto the global config params and made available to just the task being run.

##### `cmd`, `cmd!`

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  def run!
    cmd "ls -la", :env => { 'PWD' => '/path/to/some/dir' }
    cmd! "test -d some_file"
  end

end
```

Use the `cmd` helper to run local system cmds.  Pass it a string system command to run and it runs it using [Scmd](https://github.com/redding/scmd).  You can [optionally pass in an `:env` param](https://github.com/redding/scmd#environment-variables) with any ENV vars that need to be set.  A `Dk::Local::Cmd` object is returned so you can access data such as the `stdout`, `stderr` and whether the command was successful or not.

The `cmd!` helper is identical to the `cmd` helper except that it raises a `Dk::Task::CmdRunError` if the command was not successful.

##### `ssh`, `ssh!`

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  def run!
    hosts = ['1.example.com', 'user@2.example.com']
    ssh "ls -la", :hosts => hosts
    ssh! "test -d some_file", :hosts => hosts
  end

end
```

Use the `ssh` helper to run remote system cmds on hosts using ssh.  Like the normal `cmd*` helpers, pass it a string system command and it runs the command on each host using by creating a local system cmd that runs ssh.  Like `cmd*` you can optionally pass in an `:env` param with any ENV vars that need to be set locally.  Similare to `cmd*`, a `Dk::Remote::Cmd` object is returned so you can access whether the command was successful or not.

The `ssh!` helper is identical to the `ssh` helper except that it raises a `Dk::Task::SSHRunError` if the command was not successful.

##### `halt`

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  def run!
    # ... do something ...

    halt if nothing_more_to_do

    # ... otherwise keep going ...
  end

end
```

Use the `halt` helper to stop executing the current task.  This doesn't halt the entire run (callbacks, subsequent tasks, etc).  It only halts the current task.  If you want to stop running everything, just raise an exception.

##### `log_info`, `log_debug`, `log_error`

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  def run!
    log_info  "will always show up in the CLI output"
    log_debug "will only show up in the CLI output in verbose mode"
    log_error "will always show, but has special error handling"
  end

end
```

Use the `log_*` helpers to log information as the task is running.  Each corresponds to a logger level.  The CLI logs to stdout on the INFO level by default.  When run in verbose mode, it logs to stdout on the DEBUG level.  If an optional log file has been configured, the CLI will log to the file on DEBUG level regardless of any verbose mode setting.

#### Task Descriptions

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  desc "This is a task that does something"

  def run!
    # ... do something ...
  end

end
```

The descriptions of any routed tasks will be displayed when running `--help` in the CLI.

#### Task Callbacks

You can configure other tasks as callbacks to your task:

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  before         MyBeforeTask
  prepend_before MyOtherBeforeTask, :some => 'param'
  after          MyAfterTask,       :some => 'param'
  prepend_after  MyOtherAfterTask

  def run!
    # ... do something ...
  end

end
```

Each callback can be optionally configured with a set of params.  These tasks will be run in the order they are added before/after the `run!` method of the current task.  Using `halt` does not affect whether callbacks are run or not.

#### Default SSH Hosts

You can configure a default list of hosts to use for ssh commands made in a Task.  These hosts will be used on all commands that don't specify a custom `:hosts` option:

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  ssh_hosts ['1.example.com', 'user@2.example.com']

  def run!
    ssh('ls -la') # => will ssh to 1.example.com and user@2.example.com
    ssh('ls -la', :hosts => ['3.example.com']) # => will ssh to 3.example.com
  end

end
```

You can also specify a named list of hosts that have been configured:

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  ssh_hosts 'my-app-servers'

  def run!
    ssh('ls -la') # => will ssh to the configured 'my-app-servers' hosts
  end

end
```

You can also specify a proc that will be instance eval'd on the task instance:

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  ssh_hosts{ params['some-servers'] }

  def run!
    ssh('ls -la') # => will ssh to the hosts specified by the 'some-servers' param
  end

end
```

#### Testing Tasks

Dk comes with a test runner and some test helpers to assist in unit testing tasks.  The test runner doesn't run any callback tasks and captures spies for the task, cmd and ssh calls it runs.  It also turns off any logging.

```ruby
# in your test file or whatever

include Dk::Task::TestHelpers

test "my task should do something" do
  runner = test_runner(MyTask)
  runner.run
  runner.runs #=> [TaskRun, Local::CmdSpy, Remote::CmdSpey, ... ]

  # make assertions that the logic you expect to run actually ran
  task = runner.task #=> MyTask instance

  # make assertions about your task instance if needed
end
```

## Installation

Add this line to your application's Gemfile:

    gem 'dk'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dk

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
