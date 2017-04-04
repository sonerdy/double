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
      [{:double, "~> 0.4.0", only: :test}]
    end
    ```

## Usage

### Module Doubles

Module doubles are probably the most straightforward way to use Double.
You're just creating fake versions of an existing module.
You can use this module like any other module that you call functions on.

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
    inject = double(IO)
    |> allow(:puts, fn(_msg) -> :ok end)

    Example.process(inject) # inject the stub module

    # now just use the built-in ExUnit methods assert_receive/refute_receive to verify things
    assert_receive({:puts, "It works without mocking libraries"})
  end
end
```

### Map Doubles

Maps can be useful if you want to group together functions from various modules as an injectable dependency.

```elixir
defmodule Example do
  @inject %{
    puts: &IO.puts/1,
    another_service: &SomeService.process/3
  }

  def process(inject \\ @inject) do
    # Note the dot placement for function calls is different from Module-based doubles.
    inject.puts.("It works without mocking libraries")
    inject.another_service.(1, 2, 3)
  end
end

defmodule ExampleTest do
  use ExUnit.Case
  import Double

  test "example test" do
    inject = double() # by not specifying a module, double defaults to returning a map
    |> allow(:puts, fn(_msg) -> :ok end)
    |> allow(:another_service, fn(1, 2, 3) -> :ok end) # requires exactly 1, 2, 3 arguments

    Example.process(inject)

    # now just use the built-in ExUnit methods assert_receive/refute_receive to verify things
    assert_receive({:puts, "It works without mocking libraries"})
    assert_receive({:another_service, 1, 2, 3})
  end
end
```

### Struct Doubles

Using a struct behaves just like using maps, but has the benefit of throwing an error when trying to allow a non-existent key.
Structs can also be handy for re-use if you share similar dependencies throughout your app.

```elixir
defmodule Example do
  defmodule Inject do
    defstruct puts: &IO.puts/1
  end

  def process(inject \\ %Inject{}) do
    inject.puts.("It works without mocking libraries")
  end
end

defmodule ExampleTest do
  use ExUnit.Case
  import Double

  test "example test" do
    inject = double(%Example.Inject{})
    |> allow(:puts, fn(_msg) -> :ok end)

    Example.process(inject)

    # now just use the built-in ExUnit methods assert_receive/refute_receive to verify things
    assert_receive({:puts, "It works without mocking libraries"})
  end
end
```

## Features

### Basics

```elixir
# minimal function - no arguments and returns nil
stub = double(Application) |> allow(:started_applications)
stub.started_applications() #nil

# only accept specific arguments
stub = double(Application)
|> allow(:ensure_all_started, fn(:logger) -> nil end)
stub.ensure_all_started(:logger) # nil
stub.ensure_all_started(:something) # raises FunctionClauseError

# with return values
stub = double(IO) |> allow(:puts, fn("hello world") -> :ok end)
stub.puts("hello world") # :ok

# User pattern matching to accept any arguments
stub = double(ExampleModule) |> allow(:example, fn(x, y) -> :ok end)
stub.example("hello", "world") # :ok

# stub as many functions as you want
stub = double(ExampleModule)
|> allow(:example)
|> allow(:another_example)

# When using Map based doubles, you can add your own data or stubs, it's just a normal map
stub = double
|> Map.merge(%{some_value: "hello"})
|> allow(:example)
stub.some_value # "hello"
stub.example.() # nil
```

### Different return values for different arguments
```elixir
stub = double(ExampleModule)
|> allow(:example, fn("one") -> 1 end)
|> allow(:example, fn("two") -> 2 end)
|> allow(:example, fn("three") -> 3 end)

stub.example("one") # 1
stub.example("two") # 2
stub.example("three") # 3
```

### Multiple calls returning different values
```elixir
stub = double(ExampleModule)
|> allow(:example, fn("count") -> 1 end)
|> allow(:example, fn("count") -> 2 end)

stub.example("count") # 1
stub.example("count") # 2
stub.example("count") # 2
```

### Exceptions

```elixir
double = double(ExampleModule)
|> allow(:example_with_error_type, fn -> raise RuntimeError, "kaboom!" end)
|> allow(:example_with_error_type, fn -> raise "kaboom!" end)
```

### Verifying calls
If you want to verify that a particular stubbed function was actually executed,
Double ensures that a message is receivable to your test code so you can just use the built-in ExUnit `assert_receive/assert_received`.
The message is a tuple starting with the function name, and then the arguments received.

```elixir
stub = double(ExampleModule) |> allow(:example, fn("count") -> 1 end)
stub.example("count")
assert_receive({:example, "count"})
```
Remember that pattern matching is your friend so you can do all kinds of neat tricks on these messages.
```elixir
assert_receive({:example, "c" <> _rest}) # verify starts with "c"
assert_receive({:example, %{test: 1}) # pattern match map arguments
assert_receive({:example, x}) # assign an argument to x to verify another way
assert x == "count"
# the list goes on ...
```

### Module Verification

By default when using module doubles, your setups will check the source module to ensure the function exists with the correct arity.

```elixir
double(IO)
|> allow(:non_existent_function, fn(x) -> x end) # raises VerifyingDoubleError
```

### Struct Key Verification

```elixir
double = double(%MyStruct{})
|> allow(:example, fn("hello") -> "world" end) # will error if :example is not a key in MyStruct.
```
