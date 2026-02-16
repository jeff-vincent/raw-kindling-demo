FROM haskell:9.6-slim AS builder
WORKDIR /app
COPY pricing.cabal ./
RUN cabal update && cabal build --only-dependencies
COPY src ./src
RUN cabal build && cp $(cabal list-bin pricing) /pricing

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libgmp10 ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /pricing /pricing
EXPOSE 3013
CMD ["/pricing"]
