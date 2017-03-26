# Double
Double builds on-the-fly injectable dependencies for your tests.
It does NOT override behavior of existing modules or functions.

## Installation

The package can be installed as:

  1. Add `double` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:double, "~> 0.3.0", only: :test}]
    end
    ```

## Usage

### Module Doubles

Module doubles are probably the most straightforward way to use Double.
You're just creating fake versions of an existing module.
You can use this module like any other module that you call functions on.

```elixir
defmodule Example do
  def process(io \\ IO) do
    io.puts("It works without mocking libraries")
  end
end

defmodule ExampleTest do
  use ExUnit.Case
  import Double

  test "example outputs to console" do
    inject = double(IO)
    |> allow(:puts, with: {:any, 1}, returns: :ok) # {:any, x} will accept any values of arity x

    Example.process(inject)

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
    inject = double()
    |> allow(:puts, with: {:any, 1}, returns: :ok) # {:any, x} will accept any values of arity x
    |> allow(:another_service, with: [1,2,3], returns: :ok) # requires exactly 1, 2, 3 arguments

    Example.process(inject)

    # now just use the built-in ExUnit methods assert_receive/refute_receive to verify things
    assert_receive({:puts, "It works without mocking libraries"})
    assert_receive({:another_service, 1, 2, 3})
  end
end
```

### Struct Doubles

Using a struct behaves much like using maps, but has the benefit of throwing an error when trying to allow a non-existent key.
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
    |> allow(:puts, with: {:any, 1}, returns: :ok) # {:any, x} will accept any values of arity x

    Example.process(inject)

    # now just use the built-in ExUnit methods assert_receive/refute_receive to verify things
    assert_receive({:puts, "It works without mocking libraries"})
  end
end
```

## Features

### Basics

```elixir
# minimal function - no return value or arguments
stub = double(Application) |> allow(:started_applications)
stub.started_applications() #nil

# only accept specific arguments
stub = double(Application) |> allow(:ensure_all_started, with: [:logger])
stub.ensure_all_started(:logger) # nil

# setup return value
stub = double(IO) |> allow(:puts, with: ["hello world"], returns: :ok)
stub.puts("hello world") # :ok

# accept any arguments of specific arity
stub = double(ExampleModule) |> allow(:example, with: {:any, 2}, returns: :ok)
stub.example("hello", "world") # :ok

# stub as many functions as you want
stub = double(ExampleModule)
|> allow(:example)
|> allow(:another_example)

# When using Map based doubles, you can add your own data or stubs, it's just a normal map
stub = double
|> Map.merge(%{some_value: "hello"})
|> allow(:example)
double.some_value # "hello"
double.example.() # nil
```

### Different return values for different arguments
```elixir
stub = double(ExampleModule)
|> allow(:example, with: ["one"], returns: 1)
|> allow(:example, with: ["two"], returns: 2)
|> allow(:example, with: ["three"], returns: 3)

stub.example("one") # 1
stub.example("two") # 2
stub.example("three") # 3
```

### Multiple calls returning different values
```elixir
stub = double(ExampleModule)
|> allow(:example, with: ["count"], returns: 1, returns: 2)

stub.example("count") # 1
stub.example("count") # 2
stub.example("count") # 2
```

### Exceptions

```elixir
double = double(ExampleModule)
|> allow(:example_with_error_type, raises: {RuntimeError, "kaboom!"})
|> allow(:example_with_message_only, raises: "kaboom!") # defaults to RuntimeError
```

### Verifying Doubles

By default when using module doubles, your setups will check the source module to ensure the function exists with the correct arity.

```elixir
double(IO)
|> allow(:non_existent_function, with: [1]) # raises VerifyingDoubleError
```

### Struct Key Verification

```elixir
double = double(%MyStruct{})
|> allow(:example, with: ["hello"], returns: "world") # will error if :example is not a key in MyStruct.
```

### Nested Doubles
If you want to group some of your stubbed functions in a nested map, that works just like setting any other value in a map.
```elixir
double = double
|> allow(:example)
|> Map.put(:logger, double
  |> allow(:info, with: {any: 1}, returns: :ok)
  |> allow(:error, with: {any: 1}, returns: :ok)
  |> allow(:warn, with: {any: 1}, returns: :ok)
)
double.logger.info.("test") # :ok
```
