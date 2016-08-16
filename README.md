# Dk

"Why'd you name this repo dk?" "Don't know"

This is some automated task runner thingy ala cap/rake (except without all the drama, breaking changes and difficult-to-test-ness).  You define tasks using classes; these tasks do stuff (maybe run some local or remote system commands?); you write tests for these tasks; you run them with a CLI.

## Usage

First define a task:

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  desc "my task that does something great"

  def run!
    log_info "this task does something"

    # ... do something ...
  end

end
```

Now route this task with a name so it can be run from the CLI:

```ruby
# in config/dk.rb or whatever
require 'dk'

Dk.configure do

  task 'my-task', MyTask

end
```

Now run this task using the CLI:

```
$ dk -T
my-task # my task that does something great
$ dk my-task
```

### CLI

```
$ dk --help
Usage: dk [TASKS] [options]

Tasks:
    my-other-task # my other task that does something great
    my-task       # my task that does something great

Options:
    -T, --[no-]list-tasks            list all tasks available to run
    -d, --[no-]dry-run               run the tasks without executing any local/remote cmds
    -t, --[no-]tree                  print out the tree of tasks/sub-tasks that would be run
    -v, --[no-]verbose               run tasks showing verbose (ie debug log level) details
        --version
        --help
```

##### `--list-tasks` option

Use this option (or its `-T` abbrev) to list out all tasks that are available to run.  This is similar to the `-T` option on cap and rake.

```
$ dk -T
my-other-task # my other task that does something great
my-task       # my task that does something great
```

##### `--dry-run` option

This option runs the tasks and logs everything just like the live runner does.  However, this runner disables all system commands: both local commands and remote ssh commands.  Use this to see what a task would do do without running any of the system commands.

##### `--tree` option

This option runs the tasks like the live runner does and disables all system commands like the `--dry-run` option does.  However, this option also disables all logging and tracks all tasks and sub-tasks that are run.  It then outputs the tree of tasks that was run:

TODO: show task tree output example

Use this to show the user all the tasks/sub-tasks that are run and which parent tasks are running them.

##### `--verbose` option

This option runs tasks showing more verbose output/details (ie it sets the logger's stdout log level to 'debug').  All Task `log_debug` messages will be shown on stdout with this option.  This option also makes the stdout and file logs identical.

### Config

Dk stores settings in a config.  To modify the settings add a configure block:

```ruby
require 'dk'

Dk.configure do

  # settings go here...

end
```

There are a number of DSL settings that can be configured.  Use these to set param values, set default ssh settings, configure tasks that can be called from the CLI, etc.

##### `set_param`

```ruby
require 'dk'

Dk.configure do

  set_param 'app_name',         'myapp'
  set_param 'number_of_things', 5
  # ...

end
```

Use the `set_param` method to set new global param values.  Any tasks that are run will have these param values available to them using the tasks's `params` helper method.

##### `before`, `prepend_before`, `after`, `prepend_after`

You can configure tasks as callbacks on other tasks using these helper methods:

```ruby
require 'dk'

Dk.configure do

  before         MyTask, MyBeforeTask
  prepend_before MyTask, MyOtherBeforeTask, 'some_param' => 'some_value'
  after          MyTask, MyAfterTask,       'some_param' => 'some_value'
  prepend_after  MyTask, MyOtherAfterTask

end
```

Each callback can be optionally configured with a set of params.  Callbacks can either be appended or prepended (this can be especially useful when you want to control the order 3rd-party tasks are run in).

The callback tasks will be run in the order they are added before/after the `run!` method of the task they are added to.  The [`halt` task helper](https://github.com/redding/dk#halt) does not stop these callbacks from running.

##### `ssh_hosts`, `ssh_args`, `host_ssh_args`

```ruby
require 'dk'

Dk.configure do

  ssh_hosts 'all_servers', '1.example.com',
                           '2.example.com',
                           '3.example.com',
                           'user@4.example.com',
                           'user@5.example.com'

  ssh_hosts 'primary_server', '1.example.com'

  ssh_hosts 'web_servers', '1.example.com',
                           '2.example.com'

  ssh_hosts 'db_server', '3.example.com'

  ssh_hosts 'bg_servers', 'user@4.example.com',
                          'user@5.example.com'

  # these are custom args to use on all SSH cmds
  ssh_args "-o ForwardAgent=yes "\
           "-o ControlMaster=auto "\
           "-o ControlPersist=60s "\
           "-o UserKnownHostsFile=/dev/null "\
           "-o StrictHostKeyChecking=no "\
           "-o ConnectTimeout=10 "\
           "-o LogLevel=quiet "

  # these two hosts use custom SSH ports
  host_ssh_args 'user@4.example.com', '-p 12345'
  host_ssh_args 'user@5.example.com', '-p 12345'

end
```

Use the `ssh_hosts` method to define a named set of hosts.  These hosts can now be referred to by name when running `ssh` cmds in tasks.

Use the `ssh_args` and `host_ssh_args` methods to configure ssh cmd arguments to apply to all SSH cmds.  The host-specific args are only applied to SSH cmds run on the specific host.

##### `log_pattern`, `log_file`, `log_file_pattern`

```ruby
require 'dk'

Dk.configure do

  log_pattern '[%-5l] : %m\n' # [INFO] : blah blah\n"

  log_file         "log/dk.log"       # log all task run details to this file
  log_file_pattern '[%d %-5l] : %m\n' # [<datetime> INFO] : blah blah\n"

end
```

Use the `log_pattern` and `log_file_pattern` methods to override the default log entry format for stdout and file logging respectively.  By default, stdout logs just log the message while the file logs log the date level and message.  Uese these to tweak as desired.  Dk uses [Logsly](https://github.com/redding/logsly) for its loggers so check out its README for [details on using patterns](https://github.com/redding/logsly#patterns).

Use the `log_file` method to turn on file logging.  If given a file path, Dk will log all task run details (verbosely) to the file.  This is handy when problems occur running tasks in non-verbose mode.  File logging is always done verbosely so you can use this to refere to the details of previous task runs even though you may not have seen these details in your stdout logs.

##### `task`

```ruby
require 'dk'

Dk.configure do

  task 'deploy',      MyDeployTask
  task 'deploy:setup' MyDeploySetupTask

  # ...

end
```

Use the `task` method to configure tasks that are runnable via the CLI.  This also will display information about the task when using the `--help option in the CLI.

**Note**: only tasks configured using this method will be runnable from the CLI.

##### `stub_dry_tree_cmd`, `stub_dry_tree_ssh`

```ruby
require 'dk'

Dk.configure do

  stub_dry_tree_cmd("ls -la") do |spy| # spy is a Local::CmdSpy
    spy.stdout = "..."
  end

  stub_dry_tree_ssh("ls -la") do |spy| # spy is a Remote::CmdSpy
    spy.exitstatus = 1 # simulare the ssh call failing
  end

  # ...

end
```

Use the `stub_dry_tree_cmd` and `stub_dry_tree_ssh` methods to add cmd and ssh stubs when using `--dry-run` or `--tree`. This can be used to control the stdout, stderr or exitstatus of a command. This is useful when a task uses the output of one command for another command or when the task does different logic depending on if a command succeeds or fails.

### Task

#### Helper Methods

The `Dk::Task` mixin provides a bunch of helper methods to make writing tasks easier and for commonizing common functions.

##### `params`, `set_param`, `param?`, `try_param`

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  def run!
    param?('some_param')    #=> true
    params['some_param']    #=> "some value"
    try_param('some_param') #=> "some value"

    param?('some_other_param')    #=> false
    params['some_other_param']    #=> Dk::NoParamError
    try_param('some_other_param') #=> nil

    set_param('some_other_param', 'some other value')
    param?('some_other_param')    #=> true
    params['some_other_param']    #=> "some other value"
    try_param('some_other_param') #=> "some other value"
  end

end
```

Use the `param` helper to access named params that the task was run with.  Params can be added two ways: globally [from the main config](https://github.com/redding/dk#set_param) or from [callback definitions](https://github.com/redding/dk#task-callbacks) and [`run_task` calls](https://github.com/redding/dk#run_task).

Use the `set_param` method to set new global param values like you would on the main config.  Any subsequent tasks that are run will have these param values available to them.

Use the `param?` method to check whether a specific param has been set.  Prefer this over `params.key?` as the task params have special logic for interacting with any runner params that makes the traditional `key?` method unreliable.

By default, the params will raise an exception if you try and access a missing key (it will raise Dk::NoParamerror).  The idea is that Dk will loudly notify you if you are accessing a param you expect to be set and it is not set.  However, this may not be appropriate for every scenario, therefore you can use the `try_param` helper and it will just return `nil` if the param is not set.

##### `before`, `prepend_before`, `after`, `prepend_after`

[Like in the Config](https://github.com/redding/dk#before-prepend_before-after-prepend_after), you can add tasks as callbacks on other tasks using these helper methods:

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  def run!
    before         SomeTask, MyBeforeTask
    prepend_before SomeTask, MyOtherBeforeTask, 'some_param' => 'some_value'
    after          SomeTask, MyAfterTask,       'some_param' => 'some_value'
    prepend_after  SomeTask, MyOtherAfterTask
  end

end
```

Each callback can be optionally configured with a set of params.  Callbacks can either be appended or prepended (this can be especially useful when you want to control the order 3rd-party tasks are run in).  Once a callback is added, it works just as it would if added via the Config.

##### `ssh_hosts`

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  def run!
    ssh_hosts('my-app-servers') # => nil
    ssh_hosts('my-web-servers') # => nil

    ssh_hosts 'my-app-servers', '1.example.com'
    ssh_hosts 'my-web-servers', '2.example.com', '3.example.com'

    ssh_hosts('my-app-servers') # => ['1.example.com']
    ssh_hosts('my-web-servers') # => ['2.example.com', '3.example.com']
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

    run_task MyOtherTask, 'some_param' => 'some value'

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

##### `:dry_tree_run` cmd/ssh opt

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  def run!
    cmd! "test -d some_file", :dry_tree_run => true
    ssh! "test -d some_file", :dry_tree_run => true
  end

end
```

Use this option to force the cmd/ssh to *always* run, even using the `--dry-run` and `--tree` CLI options (which put Scmd in test mode and don't run any cmds by default).  The idea is that some cmds are essential to the running of the task and if they don't actually run, the task will error out.  This is handy for tasks that don't change anything they just read data and that data is used to determine how a task should proceed.  This allows you to still get the advantages of the dry run and tree CLI options.

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

You can optionally style your log messages:

```ruby
log_info "my message", :red, :on_white
log_info "my " + Dk::Ansi.styled_msg("special", :bold, :blue) + " message"
```

See `Dk::Ansi::CODES.keys` for a list of available style names.

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
  prepend_before MyOtherBeforeTask, 'some_param' => 'some_value'
  after          MyAfterTask,       'some_param' => 'some_value'
  prepend_after  MyOtherAfterTask

  def run!
    # ... do something ...
  end

end
```

Each callback can be optionally configured with a set of params.  These tasks will be run in the order they are added before/after the `run!` method of the current task.  The [`halt` helper](https://github.com/redding/dk#halt) does not stop these callbacks from running.

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

#### Ensure Tasks Only Run Once

```ruby
require 'dk/task'

class MyTask
  include Dk::Task

  run_only_once true

  def run!
    # ... do something ...
  end

end
```

Use this setting to ensure that a task only runs once no matter how many other tasks or sub-tasks either run it manually or configure it as a callback.  This is useful for "gatekeeper" tasks such as tasks that validate params, etc.  By default, tasks can run multiple times.

#### Testing Tasks

Dk comes with a test runner and some test helpers to assist in unit testing tasks.  The test runner doesn't run any callback tasks and captures spies for the task, cmd and ssh calls it runs.  It also turns off any logging.

```ruby
# in your test file or whatever

include Dk::Task::TestHelpers

test "my task should do something" do
  runner = test_runner(MyTask)
  runner.run
  runner.runs #=> [TaskRun, Local::CmdSpy, Remote::CmdSpy, ... ]

  # make assertions that the logic you expect to run actually ran
  task = runner.task #=> MyTask instance

  # make assertions about your task instance if needed
end
```

Dk's test helpers include methods for stubbing cmd and ssh calls.  This allows controlling cmd/ssh behavior such as exit status, stdout and stderr.  If a task expects to use the stdout/stderr or does special handling when a call errors then the stubbing methods can be used for testing.

```ruby
# in your test file or whatever

include Dk::Task::TestHelpers

test "my task should do something" do
  runner = test_runner(MyTask)
  runner.stub_cmd("ls -la") do |spy| # spy is a Local::CmdSpy
    spy.stdout = "..."
  end
  runner.stub_ssh("ls -la", :input => 'whatever') do |spy| # spy is a Remote::CmdSpy
    spy.exitstatus = 1 # simulare the ssh call failing
  end

  # ....
end
```

You can even stub with procs.  Those procs will be instance eval'd against the task to determine if the stub is a match.  This allows you to stub the same way the call is made in the task (which is handy when the cmds are driven by dynamic values on the task instance).

```ruby
# in your test file or whatever

include Dk::Task::TestHelpers

test "my task should do something" do
  runner = test_runner(MyTask)
  runner.stub_cmd(proc{ self.class.some_cmd_str }, :opts => proc{ some_opts }) do |spy| # spy is a Local::CmdSpy
    spy.stdout = "..."
  end
  runner.stub_ssh("ls -la", :input => proc{ some_task_input_val }) do |spy| # spy is a Remote::CmdSpy
    spy.exitstatus = 1 # simulare the ssh call failing
  end

  # ....
end
```

## Dk 3rd-party gems

These gems extend Dk for specific behavior:

* [dk-pkg](https://github.com/redding/dk-pkg): Dk logic for installing pkgs
* [dk-abdeploy](https://github.com/redding/dk-abdeploy): Dk tasks that implement the A/B deploy scheme
* [dk-dumpdb](https://github.com/redding/dk-dumpdb): Build Dk tasks to dump and restore your databases

(if you build your own gem that extends Dk, let us know and we'll link it here)

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
