# Double
Double builds on-the-fly injectable dependencies for your tests.
It does NOT override behavior of existing modules or functions.
Double uses Elixir's built-in language features such as pattern matching and message passing to
give you everything you would normally need a complex mocking tool for.

## Installation
The package can be installed as:

  1. Add `double` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:double, "~> 0.7.0", only: :test}]
  end
  ```

## Usage
Start Double in your `test/test_helper.exs` file:

```elixir
ExUnit.start
Application.ensure_all_started(:double)
```

- [Intro](#modulebehaviour-doubles)
- Stubs
    - [Basics](#basics)
    - [Advanced Return Values](#different-return-values-for-different-arguments)
    - [Exceptions](#exceptions)
    - [Verifying Calls](#verifying-calls)
- [Spies](#spies)

### Module/Behaviour Doubles
Double creates a fake module based off of a behaviour or module.
You can use this module like any other module that you call functions on.
Each stub you define will verify that the function name and arity are defined in the target module or behaviour.

```elixir
defmodule Example do
  def process(io \\ IO) do # allow an alternative dependency to be passed
    io.puts("It works without mocking libraries!")
  end
end

defmodule ExampleTest do
  use ExUnit.Case
  import Double

  test "example outputs to console" do
    io_stub = stub(IO,:puts, fn(_msg) -> :ok end)

    Example.process(io_stub) # inject the stub module

    # use built-in ExUnit assert_receive/refute_receive to verify things
    assert_receive({IO, :puts, ["It works without mocking libraries!"]})
  end
end
```

## Features
### Basics
```elixir
# Stub a function
dbl = stub(ExampleModule, :add, fn(x, y) -> x + y end)
dbl.add(2, 2) # 4

# Pattern match arguments
dbl = stub(Application, :ensure_all_started, fn(:logger) -> nil end)
dbl.ensure_all_started(:logger) # nil
dbl.ensure_all_started(:something) # raises FunctionClauseError

# Stub as many functions as you want
dbl = ExampleModule
|> stub(:add, fn(x, y) -> x + y end)
|> stub(:subtract, fn(x, y) -> x - y end)
```

### Different return values for different arguments
```elixir
dbl = ExampleModule
|> stub(:example, fn("one") -> 1 end)
|> stub(:example, fn("two") -> 2 end)
|> stub(:example, fn("three") -> 3 end)

dbl.example("one") # 1
dbl.example("two") # 2
dbl.example("three") # 3
```

### Multiple calls returning different values
```elixir
dbl = ExampleModule
|> stub(:example, fn("count") -> 1 end)
|> stub(:example, fn("count") -> 2 end)

dbl.example("count") # 1
dbl.example("count") # 2
dbl.example("count") # 2
```

### Exceptions
```elixir
dbl = ExampleModule
|> stub(:example_with_error_type, fn -> raise RuntimeError, "kaboom!" end)
|> stub(:example_with_error_type, fn -> raise "kaboom!" end)
```

### Verifying calls
If you want to verify that a particular stubbed function was actually executed,
Double ensures that a message is receivable to your test process so you can just use the built-in ExUnit `assert_receive/assert_received`.
The message is a 3-tuple `{module, :function, [arg1, arg2]}`and .

```elixir
dbl = ExampleModule
|> stub(:example, fn("count") -> 1 end)
dbl.example("count")
assert_receive({ExampleModule, :example, ["count"]})
```
Remember that pattern matching is your friend so you can do all kinds of neat tricks on these messages.
```elixir
assert_receive({ExampleModule, :example, ["c" <> _rest]}) # verify starts with "c"
assert_receive({ExampleModule, :example, [%{test: 1}]) # pattern match map arguments
assert_receive({ExampleModule, :example, [x]}) # assign an argument to x to verify another way
assert x == "count"
```

### Module Verification
By default your setups will check the source module to ensure the function exists with the correct arity.

```elixir
stub(IO, :non_existent_function, fn(x) -> x end) # raises VerifyingDoubleError
```

### Clearing Stubs
Occasionally it's useful to clear the stubs for an existing double. This is useful when you have
a shared setup and a test needs to change the way a double is stubbed without recreating the whole thing.

```elixir
dbl = IO
|> stub(:puts, fn(_) -> :ok end)
|> stub(:inspect, fn(_) -> :ok end)

# later
dbl |> clear(:puts) # clear an individual function
dbl |> clear([:puts, :inspect]) # clear a list of functions
dbl |> clear() # clear all functions
```

### Spies
Everything that works on stubs should pretty much work on spies, but the spy just automatically defaults to using the implementation of the module you're spying.

Say you have already written a stub of some kind for the `IO` module:
```
defmodule IOStub do
  def write(filename, content) do
    "really bad example of writing a file"
  end
end
```
Now in your tests you can utilize this stub and "attach" spying behavior like so:
```
test "spying on modules works" do
  # use spy/1 instead of stub
  spy = spy(IOStub)

  # The spy works just like the stub you defined.
  assert spy.write("anything", "anything") == "really bad example of writing a file"

  # But it also gives you this!
  assert_receive {IOStub, :write, ["anything", "anything"]}

  # The spy can also be stubbed if you want to override a specific function while leaving others
  stub(spy, :write, fn(_, _) -> :stubbed end)
  assert spy.write("anything", "anything") == :ok
end
```

