defmodule SpyTest do
  use ExUnit.Case, async: false
  import Double

  test "spies modules" do
    assert spy(IO) |> is_atom
  end

  test "spies erlang modules" do
    assert spy(:application) |> is_atom
  end

  test "spies function calls" do
    spy =
      TestModule
      |> spy()

    # |> stub(:process, fn 1, 2, 3 -> 1 end)

    assert spy.process(1, 2, 3) == {1, 2, 3}
    assert_receive({TestModule, :process, [1, 2, 3]})

    assert spy.another_function(42) == 42
    assert_receive({TestModule, :another_function, [42]})
  end

  test "allows multiple calls" do
    spy = TestModule |> spy()

    assert spy.process(1, 2, 3) == {1, 2, 3}
    assert spy.process(3, 2, 1) == {3, 2, 1}
    assert_receive({TestModule, :process, [1, 2, 3]})
    assert_receive({TestModule, :process, [3, 2, 1]})
  end

  test "allows subsequent stubbing of functions" do
    dbl =
      TestModule
      |> spy()
      |> stub(:process, fn 1, 2, 3 -> 2 end)

    assert dbl.process(1, 2, 3) == {1, 2, 3}
    assert dbl.process(1, 2, 3) == 2
  end

  test "clearing spy to stub a function" do
    dbl =
      TestModule
      |> spy()
      |> clear()
      |> allow(:process, fn 2 -> 2 end)

    assert dbl.process(2) == 2
    assert_receive({TestModule, :process, [2]})
  end

  test "clears individual function stubs" do
    dbl =
      TestModule
      |> spy()
      |> clear(:process)
      |> stub(:process, fn -> 2 end)

    assert dbl.process() == 2
  end
end
