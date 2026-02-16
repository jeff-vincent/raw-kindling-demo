FROM sbt:eclipse-temurin-21-alpine AS builder
WORKDIR /app
COPY build.sbt .
COPY project ./project
RUN sbt update
COPY src ./src
RUN sbt assembly

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/scala-3.3.1/streaming-assembly-0.1.0.jar app.jar
EXPOSE 3009
CMD ["java", "-jar", "app.jar"]
