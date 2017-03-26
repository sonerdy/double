defmodule CommonTests do
  defmacro test_double_behavior do
    quote do
      test "adds functions to maps", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, with: [1,2,3], returns: 1)
        assert subject.(inject, :process, [1,2,3]) == 1
        assert_receive({:process, 1, 2, 3})

        inject = allow(inject, :another_function, with: [], returns: :anything)
        assert subject.(inject, :another_function, []) == :anything
        assert_receive(:another_function)
      end

      test "allows multiple calls", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, with: [1,2,3], returns: 1)
        assert subject.(inject, :process, [1, 2, 3]) == 1
        assert subject.(inject, :process, [1, 2, 3]) == 1
      end

      test "allows subsequent calls to return new values", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process,
          with: [1,2,3],
          returns: 1,
          returns: 2,
          returns: 3
        )
        assert subject.(inject, :process, [1, 2, 3]) == 1
        assert subject.(inject, :process, [1, 2, 3]) == 2
        assert subject.(inject, :process, [1, 2, 3]) == 3
        assert subject.(inject, :process, [1, 2, 3]) == 3
      end

      test "no return value is nil", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, with: [1,2,3])
        assert subject.(inject, :process, [1, 2, 3]) == nil
      end

      test "allows any arguments", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, with: {:any, 3}, returns: 1)
        assert subject.(inject, :process, [1, 2, 3]) == 1
      end

      test "stubbing specific arguments is given priority over {:any, x}", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, with: {:any, 3}, returns: 1)
        |> allow(:process, with: [1,2,3], returns: 2)
        assert subject.(inject, :process, [1, 2, 3]) == 2
        assert subject.(inject, :process, [1, 1, 1]) == 1
      end

      test "allows empty arguments", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, with: [], returns: 1)
        assert subject.(inject, :process, []) == 1
      end

      test "without arguments setup defaults to none required", %{dbl: dbl, subject: subject} do
        inject = dbl |> allow(:process, returns: :ok)
        assert subject.(inject, :process, []) == :ok
      end

      test "allows out of order calls", %{dbl: dbl, subject: subject} do
        inject = dbl
        |> allow(:process, with: [1], returns: 1)
        |> allow(:process, with: [2], returns: 2)
        |> allow(:process, with: [3], returns: 3)
        assert subject.(inject, :process, [2]) == 2
        assert subject.(inject, :process, [1]) == 1
        assert subject.(inject, :process, [3]) == 3
        assert subject.(inject, :process, [3]) == 3
      end

      test "overwrites existing setup with same args", %{dbl: dbl, subject: subject} do
        inject = dbl
        |> allow(:process, with: [1], returns: 1)
        |> allow(:process, with: [1], returns: 2)
        assert subject.(inject, :process, [1]) == 2
        assert subject.(inject, :process, [1]) == 2
      end

      test "multiple doubles", %{dbl: dbl, dbl2: dbl2, subject: subject} do
        inject1 = dbl |> allow(:process, with: [], returns: 1)
        inject2 = dbl2 |> allow(:process, with: [], returns: 2)
        assert subject.(inject1, :process, []) == 1
        assert subject.(inject2, :process, []) == 2
      end

      test "sets up exceptions with a type of exception", %{dbl: dbl, subject: subject} do
        inject = dbl |> allow(:process, with: [], raises: {RuntimeError, "boom"})
        assert_raise RuntimeError, "boom", fn ->
          subject.(inject, :process, [])
        end
      end

      test "sets up exceptions with only a message", %{dbl: dbl, subject: subject} do
        inject = dbl |> allow(:process, with: [], raises: "boom")
        assert_raise RuntimeError, "boom", fn ->
          subject.(inject, :process, [])
        end
      end

      test "handles multiple doubles with separate setups", %{dbl: dbl, dbl2: dbl2, subject: subject} do
        double1 = dbl |> allow(:process, returns: 1)
        double2 = dbl2 |> allow(:process, returns: 2)
        assert subject.(double1, :process, []) == 1
        assert subject.(double2, :process, []) == 2
      end

    end
  end
end
