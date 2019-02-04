defmodule TestModule do
  def io_puts(x), do: x
  def sleep(x), do: x
  def process, do: nil
  def process(x), do: x
  def process(x, y, z), do: {x, y, z}
  def another_function, do: nil
  def another_function(x), do: x
  def send(a, b), do: {a, b}
end
