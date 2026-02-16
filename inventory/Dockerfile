FROM swift:5.9-jammy AS builder
WORKDIR /app
COPY Package.swift Package.resolved* ./
RUN swift package resolve
COPY Sources ./Sources
RUN swift build -c release

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y libcurl4 libxml2 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/.build/release/App /inventory
EXPOSE 3010
CMD ["/inventory", "serve", "--hostname", "0.0.0.0", "--port", "3010"]
