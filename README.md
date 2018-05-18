# Double
Double builds on-the-fly injectable dependencies for your tests.
It does NOT override behavior of existing modules or functions.
Double uses Elixir's built-in language features such as pattern matching and message passing to
give you everything you would normally need a complex mocking tool for.

Checkout [Testing Elixir: The Movie](https://youtu.be/cyU_SFyVRro) for a fun introduction to Double and unit testing in Elixir.

## Installation
The package can be installed as:

  1. Add `double` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:double, "~> 0.6.4", only: :test}]
  end
  ```

## Usage
Start Double in your `test/test_helper.exs` file:

```elixir
ExUnit.start
Application.ensure_all_started(:double)
```

### Module/Behaviour Doubles
Double creates a fake module based off of a behaviour or another module.
You can use this module like any other module that you call functions on.
Each stub you define will verify that the function name and arity are defined in the target module or behaviour.

```elixir
defmodule Example do
  def process(io \\ IO) do # allow an alternative dependency to be passed
    io.puts("It works without mocking libraries")
  end
end

defmodule ExampleTest do
  use ExUnit.Case
  import Double

  test "example outputs to console" do
    stub = IO
    |> double()
    |> allow(:puts, fn(_msg) -> :ok end)

    Example.process(stub) # inject the stub module

    # use built-in ExUnit assert_receive/refute_receive to verify things
    assert_receive({:puts, "It works without mocking libraries"})
  end
end
```

## Features
### Basics
```elixir
# Stub a function
stub = ExampleModule
|> double()
|> allow(:add, fn(x, y) -> x + y end)
stub.add(2, 2) # 4

# Pattern match arguments
stub = Application
|> double()
|> allow(:ensure_all_started, fn(:logger) -> nil end)
stub.ensure_all_started(:logger) # nil
stub.ensure_all_started(:something) # raises FunctionClauseError

# Stub as many functions as you want
stub = ExampleModule
|> double()
|> allow(:add, fn(x, y) -> x + y end)
|> allow(:subtract, fn(x, y) -> x - y end)
```

### Different return values for different arguments
```elixir
stub = ExampleModule
|> double()
|> allow(:example, fn("one") -> 1 end)
|> allow(:example, fn("two") -> 2 end)
|> allow(:example, fn("three") -> 3 end)

stub.example("one") # 1
stub.example("two") # 2
stub.example("three") # 3
```

### Multiple calls returning different values
```elixir
stub = ExampleModule
|> double()
|> allow(:example, fn("count") -> 1 end)
|> allow(:example, fn("count") -> 2 end)

stub.example("count") # 1
stub.example("count") # 2
stub.example("count") # 2
```

### Exceptions
```elixir
stub = ExampleModule
|> double()
|> allow(:example_with_error_type, fn -> raise RuntimeError, "kaboom!" end)
|> allow(:example_with_error_type, fn -> raise "kaboom!" end)
```

### Verifying calls
If you want to verify that a particular stubbed function was actually executed,
Double ensures that a message is receivable to your test process so you can just use the built-in ExUnit `assert_receive/assert_received`.
The message is a tuple starting with the function name, and then the arguments received.

```elixir
stub = ExampleModule
|> double()
|> allow(:example, fn("count") -> 1 end)
stub.example("count")
assert_receive({:example, "count"})
```
Remember that pattern matching is your friend so you can do all kinds of neat tricks on these messages.
```elixir
assert_receive({:example, "c" <> _rest}) # verify starts with "c"
assert_receive({:example, %{test: 1}) # pattern match map arguments
assert_receive({:example, x}) # assign an argument to x to verify another way
assert x == "count"
```

### Module Verification
By default your setups will check the source module to ensure the function exists with the correct arity.

```elixir
IO
|> double()
|> allow(:non_existent_function, fn(x) -> x end) # raises VerifyingDoubleError
```

### Clearing Stubs
Occasionally it's useful to clear the stubs for an existing double. This is useful when you have
a shared setup and a test needs to change the way a double is stubbed without recreating the whole thing.

```elixir
stub = IO
|> double()
|> allow(:puts, fn(_) -> :ok end)
|> allow(:inspect, fn(_) -> :ok end)

# later
stub |> clear(:puts) # clear an individual function
stub |> clear([:puts, :inspect]) # clear a list of functions
stub |> clear() # clear all functions
```

