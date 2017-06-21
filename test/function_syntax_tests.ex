defmodule FunctionSyntaxTests do
  defmacro function_syntax_behavior do
    quote do
      test "function syntax stubs functions", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, fn(1,2,3) -> 1 end)
        assert subject.(inject, :process, [1,2,3]) == 1
        assert_receive({:process, 1, 2, 3})

        inject = allow(inject, :another_function, fn -> :anything end)
        assert subject.(inject, :another_function, []) == :anything
        assert_receive(:another_function)
      end

      test "function syntax allows multiple calls", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, fn(1,2,3) -> 1 end)
        assert subject.(inject, :process, [1, 2, 3]) == 1
        assert subject.(inject, :process, [1, 2, 3]) == 1
      end

      test "function syntax allows subsequent calls to return new values", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, fn(1,2,3) -> 1 end)
        inject = allow(dbl, :process, fn(1,2,3) -> 2 end)
        inject = allow(dbl, :process, fn(1,2,3) -> 3 end)
        assert subject.(inject, :process, [1, 2, 3]) == 1
        assert subject.(inject, :process, [1, 2, 3]) == 2
        assert subject.(inject, :process, [1, 2, 3]) == 3
        assert subject.(inject, :process, [1, 2, 3]) == 3
      end

      test "function syntax works in tandem with {:any, x}", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, with: {:any, 3}, returns: 1)
        |> allow(:process, fn(1,2,3) -> 2 end)
        assert subject.(inject, :process, [1, 2, 3]) == 1
        assert subject.(inject, :process, [1, 2, 3]) == 2
        assert subject.(inject, :process, [1, 1, 1]) == 1
      end

      test "function syntax with out of order calls", %{dbl: dbl, subject: subject} do
        inject = dbl
        |> allow(:process, fn(1) -> 1 end)
        |> allow(:process, fn(2) -> 2 end)
        |> allow(:process, fn(3) -> 3 end)
        assert subject.(inject, :process, [2]) == 2
        assert subject.(inject, :process, [1]) == 1
        assert subject.(inject, :process, [3]) == 3
        assert subject.(inject, :process, [3]) == 3
      end

      test "function syntax does not overwrite existing setup with same args", %{dbl: dbl, subject: subject} do
        inject = dbl
        |> allow(:process, fn(1) -> 1 end)
        |> allow(:process, fn(1) -> 2 end)
        assert subject.(inject, :process, [1]) == 1
        assert subject.(inject, :process, [1]) == 2
      end

      test "function syntax works with pinned argument variables", %{dbl: dbl, subject: subject} do
        arg1 = "test"
        inject = dbl
        |> allow(:process, fn(^arg1) -> arg1 end)
        assert subject.(inject, :process, ["test"]) == "test"
      end

      test "function syntax exceptions with a type of exception", %{dbl: dbl, subject: subject} do
        inject = dbl |> allow(:process, fn -> raise RuntimeError, "boom" end)
        assert_raise RuntimeError, "boom", fn ->
          subject.(inject, :process, [])
        end
      end

      test "function syntax sets up exceptions with only a message", %{dbl: dbl, subject: subject} do
        inject = dbl |> allow(:process, fn -> raise "boom" end)
        assert_raise RuntimeError, "boom", fn ->
          subject.(inject, :process, [])
        end
      end

      test "function syntax multiple doubles", %{dbl: dbl, dbl2: dbl2, subject: subject} do
        inject1 = dbl |> allow(:process, fn -> 1 end)
        inject2 = dbl2 |> allow(:process, fn -> 2 end)
        assert subject.(inject1, :process, []) == 1
        assert subject.(inject2, :process, []) == 2
      end

      test "function syntax calling other modules", %{dbl: dbl, subject: subject} do
        inject = dbl |> allow(:process, fn -> :rand.uniform end)
        refute subject.(inject, :process, []) == subject.(inject, :process, [])
      end

      test "function syntax clears previous stubs", %{dbl: dbl, subject: subject} do
        inject = dbl
        |> allow(:process, fn -> 1 end)
        |> clear
        |> allow(:process, fn -> 2 end)
        assert subject.(inject, :process, []) == 2
      end

      test "function syntax clears individual function stubs", %{dbl: dbl, subject: subject} do
        inject = dbl
        |> allow(:process, fn -> 1 end)
        |> allow(:sleep, fn(1) -> :ok end)
        |> clear(:process)
        |> allow(:process, fn -> 2 end)
        assert subject.(inject, :process, []) == 2
        assert subject.(inject, :sleep, [1]) == :ok
      end

      test "function syntax clears list of function stubs", %{dbl: dbl, subject: subject} do
        inject = dbl
        |> allow(:process, fn -> 1 end)
        |> allow(:sleep, fn(1) -> :ok end)
        |> allow(:io_puts, fn(1) -> :ok end)
        |> clear([:process, :sleep])
        |> allow(:process, fn -> 2 end)
        |> allow(:sleep, fn(1) -> 2 end)
        assert subject.(inject, :process, []) == 2
        assert subject.(inject, :sleep, [1]) == 2
        assert subject.(inject, :io_puts, [1]) == :ok
      end
    end
  end
end
