defmodule FuncListTest do
  alias Double.FuncList
  use ExUnit.Case, async: true

  test "raises UndefinedFunctionError when function is not defined" do
    {:ok, pid} = GenServer.start_link(FuncList, [])
    assert_raise UndefinedFunctionError, "function nil.function_name/1 is undefined or private", fn ->
      FuncList.apply(pid, :function_name, [1])
    end
  end

  test "raises UndefinedFunctionError when function arity is wrong" do
    {:ok, pid} = GenServer.start_link(FuncList, [])
    FuncList.push(pid, :function_name, fn(_x, _y, _z) -> 1 end)
    assert_raise UndefinedFunctionError, "function nil.function_name/1 is undefined or private", fn ->
      FuncList.apply(pid, :function_name, [1])
    end
  end

  test "raises FunctionClauseError when function is defined, but args do not match" do
    {:ok, pid} = GenServer.start_link(FuncList, [])
    FuncList.push(pid, :function_name, fn(2) -> 1 end)
    assert_raise FunctionClauseError, "no function clause matching in nil.function_name/1", fn ->
      FuncList.apply(pid, :function_name, [1])
    end
  end

  test "pushes and applys a function" do
    {:ok, pid} = GenServer.start_link(FuncList, [])
    FuncList.push(pid, :function_name, fn(1) -> 1 end)
    assert FuncList.apply(pid, :function_name, [1]) == 1
  end

  test "allows multiple calls" do
    {:ok, pid} = GenServer.start_link(FuncList, [])
    FuncList.push(pid, :function_name, fn(1) -> 1 end)
    assert FuncList.apply(pid, :function_name, [1]) == 1
    assert FuncList.apply(pid, :function_name, [1]) == 1
  end

  test "allows subsequent calls to return new values" do
    {:ok, pid} = GenServer.start_link(FuncList, [])
    FuncList.push(pid, :function_name, fn(1) -> 1 end)
    FuncList.push(pid, :function_name, fn(1) -> 2 end)
    assert FuncList.apply(pid, :function_name, [1]) == 1
    assert FuncList.apply(pid, :function_name, [1]) == 2
    assert FuncList.apply(pid, :function_name, [1]) == 2
  end

  test "pushes functions with different names" do
    {:ok, pid} = GenServer.start_link(FuncList, [])
    FuncList.push(pid, :function1, fn(1) -> 1 end)
    FuncList.push(pid, :function2, fn(1) -> 2 end)
    assert FuncList.apply(pid, :function1, [1]) == 1
    assert FuncList.apply(pid, :function2, [1]) == 2
  end

  test "properly uses pattern matching" do
    {:ok, pid} = GenServer.start_link(FuncList, [])
    FuncList.push(pid, :tuple_match, fn({:test, x}) -> x end)
    assert FuncList.apply(pid, :tuple_match, [{:test, 1}]) == 1

    FuncList.push(pid, :map_match, fn(%{test: x}) -> x end)
    assert FuncList.apply(pid, :map_match, [%{test: 1}]) == 1
  end

  test "works with zero arguments" do
    {:ok, pid} = GenServer.start_link(FuncList, [])
    FuncList.push(pid, :function_name, fn() -> 1 end)
    assert FuncList.apply(pid, :function_name, []) == 1
  end

  test "allows out of order calls" do
    {:ok, pid} = GenServer.start_link(FuncList, [])
    FuncList.push(pid, :function_name, fn(1) -> 1 end)
    FuncList.push(pid, :function_name, fn(2) -> 2 end)
    FuncList.push(pid, :function_name, fn(3) -> 3 end)
    assert FuncList.apply(pid, :function_name, [2]) == 2
    assert FuncList.apply(pid, :function_name, [1]) == 1
    assert FuncList.apply(pid, :function_name, [3]) == 3
    assert FuncList.apply(pid, :function_name, [3]) == 3
  end

  test "raises exceptions properly" do
    {:ok, pid} = GenServer.start_link(FuncList, [])
    FuncList.push(pid, :function_name, fn -> raise "Test Error" end)
    assert_raise RuntimeError, "Test Error", fn ->
      FuncList.apply(pid, :function_name, [])
    end
  end
end
