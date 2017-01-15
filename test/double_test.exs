defmodule DoubleTest do
  use ExUnit.Case, async: false
  import Double

  defmodule TestStruct do
    defstruct io_puts: &IO.puts/1, sleep: &:timer.sleep/1
  end

  describe "double" do
    test "creates a map" do
      assert is_map(double) == true
    end

    test "can return structs" do
      {%TestStruct{}} = {double(%TestStruct{})}
    end
  end

  describe "allow" do
    test "adds functions to maps" do
      inject = allow(double(), :process, with: [1,2,3], returns: 1)
      assert inject.process.(1, 2, 3) == 1
      assert_receive({:process, 1, 2, 3})

      inject = allow(inject, :another_function, with: [], returns: :anything)
      assert inject.another_function.() == :anything
      assert_receive(:another_function)
    end

    test "allows multiple calls" do
      inject = allow(double(), :process, with: [1,2,3], returns: 1)
      assert inject.process.(1, 2, 3) == 1
      assert inject.process.(1, 2, 3) == 1
    end

    test "allows subsequent calls to return new values" do
      inject = allow(double(), :process,
        with: [1,2,3],
        returns: 1,
        returns: 2,
        returns: 3
      )
      assert inject.process.(1, 2, 3) == 1
      assert inject.process.(1, 2, 3) == 2
      assert inject.process.(1, 2, 3) == 3
      assert inject.process.(1, 2, 3) == 3
    end

    test "no return value is nil" do
      inject = allow(double(), :process, with: [1,2,3])
      assert inject.process.(1, 2, 3) == nil
    end

    test "allows any arguments" do
      inject = allow(double(), :process, with: {:any, 3}, returns: 1)
      assert inject.process.(1, 2, 3) == 1
    end

    test "respects arity on any args" do
      inject = allow(double(), :process, with: {:any, 3}, returns: 1)
      assert_raise BadArityError, fn ->
        inject.process.(1) == 1
      end
    end

    test "allows empty arguments" do
      inject = allow(double(), :process, with: [], returns: 1)
      assert inject.process.() == 1
    end

    test "without arguments setup defaults to none required" do
      inject = double |> allow(:process, returns: :ok)
      assert inject.process.() == :ok
    end

    test "without options returns nil" do
      inject = double |> allow(:process)
      assert inject.process.() == nil
    end

    test "allows out of order calls" do
      inject = double
      |> allow(:process, with: [1], returns: 1)
      |> allow(:process, with: [2], returns: 2)
      |> allow(:process, with: [3], returns: 3)
      assert inject.process.(2) == 2
      assert inject.process.(1) == 1
      assert inject.process.(3) == 3
      assert inject.process.(3) == 3
    end

    test "overwrites existing setup with same args" do
      inject = double
      |> allow(:process, with: [1], returns: 1)
      |> allow(:process, with: [1], returns: 2)
      assert inject.process.(1) == 2
      assert inject.process.(1) == 2
    end

    test "keeps existing data in maps between stub calls" do
      inject = double(%{im_here: 1})
      |> allow(:process, with: [], returns: 1)
      |> put_in([:dont_kill_me], 1)
      |> allow(:hello, with: [], returns: "world")
      assert inject.dont_kill_me == 1
      assert inject.im_here == 1
      assert inject.process.() == 1
      assert inject.hello.() == "world"
    end

    test "calling double a second time works" do
      inject1 = double |> allow(:process, with: [], returns: 1)
      inject2 = double |> allow(:process2, with: [], returns: 2)
      assert inject1.process.() == 1
      assert inject2.process2.() == 2
    end

    test "nesting the stub is possible" do
      inject = allow(double, :process, with: [], returns: 1)
      |> Map.put(:logger, double
        |> allow(:error, with: ["boom"], returns: :ok)
      )
      assert inject.process.() == 1
      assert inject.logger.error.("boom") == :ok
    end

    test "sets up exceptions with a type of exception" do
      inject = double |> allow(:process, with: [], raises: {RuntimeError, "boom"})
      assert_raise RuntimeError, "boom", fn ->
        inject.process.()
      end
    end

    test "sets up exceptions with only a message" do
      inject = double |> allow(:process, with: [], raises: "boom")
      assert_raise RuntimeError, "boom", fn ->
        inject.process.()
      end
    end
  end

  describe "expect" do
    test "passes verification when all calls are made appropriately" do
      inject = double |> expect(:process)
      |> expect(:process2, with: [1,2,3])
      |> expect(:process3, with: {:any, 2})
      inject.process.()
      inject.process2.(1, 2, 3)
      inject.process3.("hello", "world")
      assert verify_doubles == :ok
    end

    test "fails verification when an expected function was not called" do
      inject = double |> expect(:process)
      assert_raise Double.DoubleVerificationError, "\n\nExpected to receive :process. Mailbox contained: []", fn ->
        verify_doubles
      end
    end

    test "fails verification when one of many messsages is not received" do
      inject = double |> expect(:process)
      |> expect(:process2)
      |> expect(:process3)
      inject.process.()
      inject.process3.()
      assert_raise Double.DoubleVerificationError, fn ->
        verify_doubles
      end
    end

    test "fails verification when calls are out of order" do
      inject = double |> expect(:process)
      |> expect(:process2)
      |> expect(:process3)
      inject.process.()
      inject.process3.()
      inject.process2.()
      assert_raise Double.DoubleVerificationError, fn ->
        verify_doubles
      end
    end
  end

  describe "using structs" do
    test "allow can stub a function for a struct", inject \\ %TestStruct{} do
      inject = double(inject)
      |> allow(:io_puts, with: ["hello world"], returns: :ok)
      assert inject.io_puts.("hello world") == :ok
    end

    test "stubbing a struct with an unknown key fails" do
      assert_raise ArgumentError, "The struct Elixir.DoubleTest.TestStruct does not contain key: boom. Use a Map if you want to add dynamic function names.", fn ->
        inject = double(%TestStruct{})
        |> allow(:boom, with: [1], returns: :ok)
        assert inject.boom.(1) == :ok
      end
    end
  end
end
