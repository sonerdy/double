# Double

Double is a simple library to help build injectable dependencies for your tests.
It does NOT override behavior of existing modules or functions.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `double` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:double, "~> 0.1.0"}]
    end
    ```

## Usage

The first step is to make sure the function you want to test will have it's dependencies injected.
This library requires usage of maps, but maybe in future versions we can do something different.

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

Now for an example on how to test this interaction.

```elixir
defmodule ExampleTest do
  use ExUnit.Case
  import Double

  test "example interacts with things" do
    inject = double
    |> allow(:puts, with: {:any, 1}, returns: :ok) # {:any, x} will accept any values of arity x
    |> allow(:some_service, with: [1, 2, 3], returns: :ok) # strictly accepts 3 arguments

    Example.process(inject)

    # now just use the built-in ExUnit methods assert_receive/refute_receive to verify things
    assert_receive({:puts, "It works without mocking librarires"})
    assert_receive({:some_service, 1, 2, 3})
  end
end
```

## More Features

You can stub the same function with different args and return values.
```elixir
double = double
|> allow(:example, with: [1], returns: 1)
|> allow(:example, with: [2], returns: 2)
|> allow(:example, with: [3], returns: 3)

double.example.(1) # 1
double.example.(2) # 2
double.example.(3) # 3
```

You can stub the same function with the same args and different return values on subsequent calls.
```elixir
double = double
|> allow(:example, with: [1], returns: 1)
|> allow(:example, with: [1], returns: 2)

double.example.(1) # 2 the last setup is the first one to return
double.example.(1) # 1
double.example.(1) # 1 continues to return 1 until more return values are configured
```

