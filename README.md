# Double
Double is a simple library to help build injectable dependencies for your tests.
It does NOT override behavior of existing modules or functions.

## Installation

The package can be installed as:

  1. Add `double` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:double, "~> 0.1.2", only: :test}]
    end
    ```

## Usage

The first step is to make sure the function you want to test will have it's dependencies injected.
This library requires usage of a map or struct:

### With Map
```elixir
defmodule Example do
  @inject %{
    puts: &IO.puts/1,
    some_service: &SomeService.process/3,
  }

  def process(inject \\ @inject)
    inject.puts.("It works without mocking libraries")
    inject.some_service.(1, 2, 3)
  end
end
```

### With Struct

Using a struct has the benefit of throwing an error when trying to allow a non-existent key, and
you may also re-use your struct if you share similar dependencies throughout your app.

```elixir
defmodule Example do
  defmodule Inject do
    defstruct puts: &IO.puts/1, some_service: &SomeService.process/3
  end

  def process(inject \\ %Inject{})
    inject.puts.("It works without mocking libraries")
    inject.some_service.(1, 2, 3)
  end
end

```

### Setting up your doubles

```elixir
defmodule ExampleTest do
  use ExUnit.Case
  import Double

  test "example interacts with things" do
    inject = double
    |> allow(:puts, with: {:any, 1}, returns: :ok) # {:any, x} will accept any values of arity x
    |> allow(:some_service, with: [1, 2, 3], returns: :ok) # strictly accepts these three arguments

    Example.process(inject)

    # now just use the built-in ExUnit methods assert_receive/refute_receive to verify things
    assert_receive({:puts, "It works without mocking librarires"})
    assert_receive({:some_service, 1, 2, 3})
  end
end
```

## Features

### Basics

```elixir
# no return value or arguments
double = double |> allow(:example)
double.example.() #nil

# only accept specific arguments
double = double |> allow(:example, with: ["hello world"])
double.example.("hello world") # nil

# setup return value
double = double |> allow(:example, with: ["hello world"], returns: :ok)
double.example.("hello world") # :ok

# accept any arguments of specific arity
double = double |> allow(:example, with: {:any, 2}, returns: :ok)
double.example.("hello", "world") # :ok

# stub as many functions as you want
double = double
|> allow(:example)
|> allow(:another_example)

# you can even add your own data or stubs to the map, it's just a normal map
double = double
|> Map.merge(%{some_value: "hello"})
|> allow(:example)
double.some_value # "hello"
double.example.() # nil
```

### Different return values for different arguments
```elixir
double = double
|> allow(:example, with: ["one"], returns: 1)
|> allow(:example, with: ["two"], returns: 2)
|> allow(:example, with: ["three"], returns: 3)

double.example.("one") # 1
double.example.("two") # 2
double.example.("three") # 3
```

### Multiple calls returning different values
```elixir
double = double
|> allow(:example, with: ["count"], returns: 1, returns: 2)

double.example.("count") # 1
double.example.("count") # 2
double.example.("count") # 2
```

### Struct key verification

```elixir
double = double(%MyStruct{})
|> allow(:example, with: ["hello"], returns: "world") # will error if :example is not a key in MyStruct.
```

### Exceptions

```elixir
double = double
|> allow(:example_with_error_type, raises: {RuntimeError, "kaboom!"})
|> allow(:example_with_message_only, raises: "kaboom!") # defaults to RuntimeError
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
