FROM clojure:temurin-21-lein-alpine AS builder
WORKDIR /app
COPY project.clj .
RUN lein deps
COPY src ./src
RUN lein uberjar

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/uberjar/reviews-0.1.0-standalone.jar app.jar
EXPOSE 3012
CMD ["java", "-jar", "app.jar"]
