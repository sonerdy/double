defmodule StubTest do
  use ExUnit.Case, async: false
  import Double

  test "stubs modules" do
    assert stub(IO) |> is_atom
  end

  test "stubs erlang modules" do
    assert stub(:application) |> is_atom
  end

  test "stubs functions" do
    dbl =
      TestModule
      |> stub()
      |> stub(:process, fn 1, 2, 3 -> 1 end)

    assert dbl.process(1, 2, 3) == 1
    assert_receive({TestModule, :process, [1, 2, 3]})

    dbl = stub(dbl, :another_function, fn -> :anything end)
    assert dbl.another_function() == :anything
    assert_receive({TestModule, :another_function, []})
  end

  test "stubs functions without calling stub/1 first" do
    dbl =
      TestModule
      |> stub(:process, fn 1, 2, 3 -> 1 end)

    assert dbl.process(1, 2, 3) == 1
    assert_receive({TestModule, :process, [1, 2, 3]})

    dbl = stub(dbl, :another_function, fn -> :anything end)
    assert dbl.another_function() == :anything
    assert_receive({TestModule, :another_function, []})
  end

  test "allows multiple calls" do
    dbl =
      TestModule
      |> stub(:process, fn 1, 2, 3 -> 1 end)

    assert dbl.process(1, 2, 3) == 1
    assert dbl.process(1, 2, 3) == 1
  end

  test "allows subsequent calls to return new values" do
    dbl =
      TestModule
      |> stub(:process, fn 1, 2, 3 -> 1 end)
      |> stub(:process, fn 1, 2, 3 -> 2 end)
      |> stub(:process, fn 1, 2, 3 -> 3 end)

    assert dbl.process(1, 2, 3) == 1
    assert dbl.process(1, 2, 3) == 2
    assert dbl.process(1, 2, 3) == 3
    assert dbl.process(1, 2, 3) == 3
  end

  test "with out of order calls" do
    dbl =
      TestModule
      |> stub(:process, fn 1 -> 1 end)
      |> stub(:process, fn 2 -> 2 end)
      |> stub(:process, fn 3 -> 3 end)

    assert dbl.process(2) == 2
    assert dbl.process(1) == 1
    assert dbl.process(3) == 3
    assert dbl.process(3) == 3
  end

  test "does not overwrite existing setup with same args" do
    dbl =
      TestModule
      |> stub(:process, fn 1 -> 1 end)
      |> stub(:process, fn 1 -> 2 end)

    assert dbl.process(1) == 1
    assert dbl.process(1) == 2
  end

  test "works with pinned argument variables" do
    arg1 = "test"

    dbl =
      TestModule
      |> stub(:process, fn ^arg1 -> arg1 end)

    assert dbl.process("test") == "test"
  end

  test "stubbed exceptions" do
    dbl =
      TestModule
      |> stub(:process, fn -> raise RuntimeError, "boom" end)

    assert_raise RuntimeError, "boom", fn ->
      dbl.process()
    end
  end

  test "sets up exceptions with only a message" do
    dbl =
      TestModule
      |> stub(:process, fn -> raise "boom" end)

    assert_raise RuntimeError, "boom", fn ->
      dbl.process()
    end
  end

  test "multiple doubles" do
    dbl1 = TestModule |> stub(:process, fn -> 1 end)
    dbl2 = TestModule |> stub(:process, fn -> 2 end)

    assert dbl1.process() == 1
    assert dbl2.process() == 2
  end

  test "calling other modules within stub" do
    dbl =
      TestModule
      |> stub(:process, fn -> :rand.uniform() end)

    refute dbl.process() == dbl.process()
  end

  test "clearing previous stubs" do
    dbl =
      TestModule
      |> stub(:process, fn 1 -> 1 end)
      |> clear()
      |> allow(:process, fn 2 -> 2 end)

    assert dbl.process(2) == 2
    refute_receive({TestModule, :process, [1]})
    assert_receive({TestModule, :process, [2]})
  end

  test "clears individual function stubs" do
    dbl =
      TestModule
      |> stub(:process, fn -> 1 end)
      |> stub(:sleep, fn 1 -> :ok end)
      |> clear(:process)
      |> stub(:process, fn -> 2 end)

    assert dbl.process() == 2
    assert dbl.sleep(1) == :ok
  end

  test "clears list of function stubs" do
    dbl =
      TestModule
      |> stub(:process, fn -> 1 end)
      |> stub(:sleep, fn 1 -> :ok end)
      |> stub(:io_puts, fn 1 -> :ok end)
      |> clear([:process, :sleep])
      |> stub(:process, fn -> 2 end)
      |> stub(:sleep, fn 1 -> 2 end)

    assert dbl.process() == 2
    assert dbl.sleep(1) == 2
    assert dbl.io_puts(1) == :ok
  end

  test "module names include source name" do
    dbl = stub(TestModule)
    assert "TestModuleDouble" <> _ = Atom.to_string(dbl)
  end

  test "functions are verified against target module" do
    assert_raise VerifyingDoubleError,
                 ~r/The function 'non_existent_function\/1' is not defined in :TestModuleDouble/,
                 fn ->
                   stub(TestModule, :non_existent_function, fn _ -> 1 end)
                 end
  end

  test "works with erlang modules" do
    dbl =
      stub(:application)
      |> stub(:loaded_applications, fn -> :ok end)

    assert dbl.loaded_applications() == :ok
  end

  test "verifies valid behavior doubles" do
    dbl = stub(TestBehaviour, :process, fn nil -> :ok end)

    assert :ok = dbl.process(nil)
  end

  test "verifies invalid behaviour doubles" do
    assert_raise VerifyingDoubleError,
                 ~r/The function 'non_existent_function\/1' is not defined in :TestBehaviourDouble/,
                 fn ->
                   stub(TestBehaviour, :non_existent_function, fn _ -> :ok end)
                 end
  end

  test "works with modules having macros" do
    # Logger.info/1 is a macro
    dbl =
      Logger
      |> stub(:info, fn _msg -> :ok end)

    assert :ok = dbl.info(nil)

    dbl =
      Mix.Task
      |> stub(:run, fn _, _ -> :ok end)

    assert :ok = dbl.run(nil, nil)
  end

  test "works normally when called within another process" do
    dbl =
      TestModule
      |> stub(:process, fn -> :ok end)

    spawn(fn ->
      dbl.process()
    end)

    assert_receive {TestModule, :process, []}
  end
end
