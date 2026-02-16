FROM elixir:1.16-alpine AS builder
RUN apk add --no-cache build-base
WORKDIR /app
ENV MIX_ENV=prod
COPY mix.exs mix.lock* ./
RUN mix local.hex --force && mix local.rebar --force && mix deps.get --only prod && mix deps.compile
COPY lib ./lib
RUN mix compile && mix release

FROM alpine:3.19
RUN apk add --no-cache libstdc++ openssl ncurses-libs
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/recommendations ./
EXPOSE 3008
CMD ["bin/recommendations", "start"]
