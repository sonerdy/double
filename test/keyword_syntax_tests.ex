defmodule KeywordSyntaxTests do
  defmacro keyword_syntax_behavior do
    quote do
      test "keyword syntax without options, returns nil", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process)
        assert subject.(inject, :process, []) == nil
        assert_receive(:process)
      end

      test "keyword syntax stubs functions", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, with: [1, 2, 3], returns: 1)
        assert subject.(inject, :process, [1, 2, 3]) == 1
        assert_receive({:process, 1, 2, 3})

        inject = allow(inject, :another_function, with: [], returns: :anything)
        assert subject.(inject, :another_function, []) == :anything
        assert_receive(:another_function)
      end

      test "keyword syntax allows multiple calls", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, with: [1, 2, 3], returns: 1)
        assert subject.(inject, :process, [1, 2, 3]) == 1
        assert subject.(inject, :process, [1, 2, 3]) == 1
      end

      test "keyword syntax allows subsequent calls to return new values", %{
        dbl: dbl,
        subject: subject
      } do
        inject =
          allow(dbl, :process,
            with: [1, 2, 3],
            returns: 1,
            returns: 2,
            returns: 3
          )

        assert subject.(inject, :process, [1, 2, 3]) == 1
        assert subject.(inject, :process, [1, 2, 3]) == 2
        assert subject.(inject, :process, [1, 2, 3]) == 3
        assert subject.(inject, :process, [1, 2, 3]) == 3
      end

      test "keyword syntax with no return value is nil", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, with: [1, 2, 3])
        assert subject.(inject, :process, [1, 2, 3]) == nil
      end

      test "keyword syntax allows any arguments", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, with: {:any, 3}, returns: 1)
        assert subject.(inject, :process, [1, 2, 3]) == 1
      end

      test "keyword syntax stubbing specific arguments works in tandem with {:any, x}", %{
        dbl: dbl,
        subject: subject
      } do
        inject =
          allow(dbl, :process, with: {:any, 3}, returns: 1)
          |> allow(:process, with: [1, 2, 3], returns: 2)

        assert subject.(inject, :process, [1, 2, 3]) == 1
        assert subject.(inject, :process, [1, 2, 3]) == 2
        assert subject.(inject, :process, [1, 1, 1]) == 1
      end

      test "keyword syntax allows empty arguments", %{dbl: dbl, subject: subject} do
        inject = allow(dbl, :process, with: [], returns: 1)
        assert subject.(inject, :process, []) == 1
      end

      test "keyword syntax without arguments setup defaults to none required", %{
        dbl: dbl,
        subject: subject
      } do
        inject = dbl |> allow(:process, returns: :ok)
        assert subject.(inject, :process, []) == :ok
      end

      test "keyword syntax allows out of order calls", %{dbl: dbl, subject: subject} do
        inject =
          dbl
          |> allow(:process, with: [1], returns: 1)
          |> allow(:process, with: [2], returns: 2)
          |> allow(:process, with: [3], returns: 3)

        assert subject.(inject, :process, [2]) == 2
        assert subject.(inject, :process, [1]) == 1
        assert subject.(inject, :process, [3]) == 3
        assert subject.(inject, :process, [3]) == 3
      end

      test "keyword syntax does not overwrite existing setup with same args", %{
        dbl: dbl,
        subject: subject
      } do
        inject =
          dbl
          |> allow(:process, with: [1], returns: 1)
          |> allow(:process, with: [1], returns: 2)

        assert subject.(inject, :process, [1]) == 1
        assert subject.(inject, :process, [1]) == 2
      end

      test "keyword syntax with multiple doubles", %{dbl: dbl, dbl2: dbl2, subject: subject} do
        inject1 = dbl |> allow(:process, with: [], returns: 1)
        inject2 = dbl2 |> allow(:process, with: [], returns: 2)
        assert subject.(inject1, :process, []) == 1
        assert subject.(inject2, :process, []) == 2
      end

      test "keyword syntax sets up exceptions with a type of exception", %{
        dbl: dbl,
        subject: subject
      } do
        inject = dbl |> allow(:process, with: [], raises: {RuntimeError, "boom"})

        assert_raise RuntimeError, "boom", fn ->
          subject.(inject, :process, [])
        end
      end

      test "keyword syntax sets up exceptions with only a message", %{dbl: dbl, subject: subject} do
        inject = dbl |> allow(:process, with: [], raises: "boom")

        assert_raise RuntimeError, "boom", fn ->
          subject.(inject, :process, [])
        end
      end

      test "clears previous stubs", %{dbl: dbl, subject: subject} do
        inject =
          dbl
          |> allow(:process, with: [], returns: 1)
          |> clear
          |> allow(:process, with: [], returns: 2)

        assert subject.(inject, :process, []) == 2
      end

      test "clears individual function stubs", %{dbl: dbl, subject: subject} do
        inject =
          dbl
          |> allow(:process, with: [], returns: 1)
          |> allow(:sleep, with: [1], returns: :ok)
          |> clear(:process)
          |> allow(:process, with: [], returns: 2)

        assert subject.(inject, :process, []) == 2
        assert subject.(inject, :sleep, [1]) == :ok
      end

      test "clears list of function stubs", %{dbl: dbl, subject: subject} do
        inject =
          dbl
          |> allow(:process, with: [], returns: 1)
          |> allow(:sleep, with: [1], returns: :ok)
          |> allow(:io_puts, with: [1], returns: :ok)
          |> clear([:process, :sleep])
          |> allow(:process, with: [], returns: 2)
          |> allow(:sleep, with: [1], returns: 2)

        assert subject.(inject, :process, []) == 2
        assert subject.(inject, :sleep, [1]) == 2
        assert subject.(inject, :io_puts, [1]) == :ok
      end
    end
  end
end
