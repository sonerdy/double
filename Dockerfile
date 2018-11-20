FROM elixir
ADD . .
RUN mix local.hex --force
RUN mix deps.get
RUN mix compile
RUN mix test
