Code.require_file("./test/keyword_syntax_tests.ex")
Code.require_file("./test/function_syntax_tests.ex")

defmodule DoubleTest do
  use ExUnit.Case, async: false
  import KeywordSyntaxTests
  import FunctionSyntaxTests
  import Double

  defmodule TestStruct do
    defstruct io_puts: &IO.puts/1,
              sleep: &:timer.sleep/1,
              process: &:timer.sleep/1,
              another_function: &:timer.sleep/1
  end

  defp maps(context) do
    context
    |> Map.merge(%{
      dbl: double(),
      dbl2: double(),
      subject: fn dbl, function_name, args ->
        apply(dbl[function_name], args)
      end
    })
  end

  defp modules(context) do
    context
    |> Map.merge(%{
      dbl: double(TestModule),
      dbl2: double(TestModule),
      subject: fn dbl, function_name, args ->
        apply(dbl, function_name, args)
      end
    })
  end

  defp structs(context) do
    context
    |> Map.merge(%{
      dbl: double(%TestStruct{}),
      dbl2: double(%TestStruct{}),
      subject: fn dbl, function_name, args ->
        apply(Map.get(dbl, function_name), args)
      end
    })
  end

  describe "double" do
    test "creates a map" do
      assert double() |> is_map()
    end

    test "can return structs" do
      %TestStruct{} = double(%TestStruct{})
    end

    test "stubs modules" do
      assert double(IO) |> is_atom
    end

    test "stubs erlang modules" do
      assert double(:application) |> is_atom
    end
  end

  describe "Map doubles" do
    setup [:maps]

    keyword_syntax_behavior()
    function_syntax_behavior()

    test "keeps existing data in maps between stub calls", %{dbl: dbl, subject: subject} do
      inject =
        dbl
        |> Map.merge(%{im_here: 1})
        |> allow(:process, with: [], returns: 1)
        |> put_in([:dont_kill_me], 1)
        |> allow(:hello, with: [], returns: "world")

      assert inject.dont_kill_me == 1
      assert inject.im_here == 1
      assert subject.(inject, :process, []) == 1
      assert subject.(inject, :hello, []) == "world"
    end

    test "nesting the stub is possible", %{dbl: dbl, dbl2: dbl2, subject: subject} do
      inject =
        allow(dbl, :process, with: [], returns: 1)
        |> Map.put(
          :logger,
          dbl2
          |> allow(:error, with: ["boom"], returns: :ok)
        )

      assert subject.(inject, :process, []) == 1
      assert subject.(inject.logger, :error, ["boom"]) == :ok
    end

    test "respects arity on any args", %{dbl: dbl, subject: subject} do
      inject = allow(dbl, :process, with: {:any, 3}, returns: 1)

      assert_raise BadArityError, fn ->
        subject.(inject, :process, [1]) == 1
      end
    end
  end

  describe "Struct doubles" do
    setup [:structs]

    keyword_syntax_behavior()
    function_syntax_behavior()

    test "allow can stub a function for a struct", %{dbl: dbl, subject: subject} do
      dbl = allow(dbl, :io_puts, with: ["hello world"], returns: :ok)
      assert subject.(dbl, :io_puts, ["hello world"]) == :ok
      %TestStruct{} = dbl
    end

    test "stubbing a struct with an unknown key fails", %{dbl: dbl, subject: subject} do
      assert_raise ArgumentError,
                   "The struct Elixir.DoubleTest.TestStruct does not contain key: boom. Use a Map if you want to add dynamic function names.",
                   fn ->
                     dbl = allow(dbl, :boom, with: [1], returns: :ok)
                     assert subject.(dbl, :boom, [1]) == :ok
                   end
    end
  end

  describe "Module doubles" do
    setup [:modules]

    keyword_syntax_behavior()
    function_syntax_behavior()

    test "module names include source name", %{dbl: dbl} do
      assert "TestModuleDouble" <> _ = Atom.to_string(dbl)
    end

    test "module doubles are strict by default", %{dbl: dbl} do
      assert_raise VerifyingDoubleError,
                   ~r/The function 'non_existent_function\/1' is not defined in :TestModuleDouble/,
                   fn ->
                     allow(dbl, :non_existent_function, with: {:any, 1}, returns: 1)
                   end
    end

    test "verification can be turned off" do
      dbl = double(TestModule, verify: false)
      allow(dbl, :non_existent_function, with: {:any, 1}, returns: 1)
      assert dbl.non_existent_function(1) == 1
    end

    test "works with erlang modules" do
      dbl =
        double(:application, verify: true)
        |> allow(:loaded_applications, fn -> :ok end)

      assert dbl.loaded_applications() == :ok
    end

    test "can override kernel functions" do
      dbl =
        double(TestModule)
        |> allow(:send, fn _, _ -> :ok end)

      assert dbl.send(:a, :b) == :ok
    end

    test "verifies valid behavior doubles" do
      dbl =
        TestBehaviour
        |> double
        |> allow(:process, fn nil -> :ok end)

      assert :ok = dbl.process(nil)
    end

    test "verifies invalid behaviour doubles" do
      dbl = TestBehaviour |> double

      assert_raise VerifyingDoubleError,
                   ~r/The function 'non_existent_function\/1' is not defined in :TestBehaviourDouble/,
                   fn ->
                     allow(dbl, :non_existent_function, fn _ -> :ok end)
                   end
    end

    test "works with modules having macros" do
      # Logger.info/1 is a macro
      dbl =
        Logger
        |> double
        |> allow(:info, fn _msg -> :ok end)

      assert :ok = dbl.info(nil)

      dbl =
        Mix.Task
        |> double
        |> allow(:run, fn _, _ -> :ok end)

      assert :ok = dbl.run(nil, nil)
    end
  end

  test "works normally when called within another process" do
    inject = double() |> allow(:some_function, with: [], returns: :ok)

    spawn(fn ->
      inject.some_function.()
    end)

    assert_receive :some_function
  end
end
