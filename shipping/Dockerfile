FROM dart:stable AS builder
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN dart pub get
COPY . .
RUN dart compile exe bin/server.dart -o bin/shipping

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/bin/shipping /shipping
EXPOSE 3011
CMD ["/shipping"]
