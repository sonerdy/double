defmodule DoubleTest do
  use ExUnit.Case, async: false
  import Double
  doctest Double

  describe "double" do
    test "creates a map" do
      assert is_map(double) == true
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
      inject = allow(double(), :process, with: [1,2,3], returns: 1)
      |> allow(:process, with: [1,2,3], returns: 2)
      |> allow(:process, with: [1,2,3], returns: 3)
      assert inject.process.(1, 2, 3) == 3
      assert inject.process.(1, 2, 3) == 2
      assert inject.process.(1, 2, 3) == 1
      assert inject.process.(1, 2, 3) == 1
    end

    test "allows any arguments" do
      inject = allow(double(), :process, with: {:any, 3}, returns: 1)
      assert inject.process.(1, 2, 3) == 1
    end

    test "allows empty arguments" do
      inject = allow(double(), :process, with: [], returns: 1)
      assert inject.process.() == 1
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
  end
end
