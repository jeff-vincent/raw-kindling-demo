ThisBuild / scalaVersion := "3.3.1"
ThisBuild / version := "0.1.0"

lazy val root = (project in file("."))
  .settings(
    name := "streaming",
    libraryDependencies ++= Seq(
      "com.typesafe.akka" %% "akka-actor-typed" % "2.8.5",
      "com.typesafe.akka" %% "akka-stream" % "2.8.5",
      "com.typesafe.akka" %% "akka-http" % "10.5.3",
      "com.typesafe.akka" %% "akka-http-spray-json" % "10.5.3",
      "org.apache.kafka" % "kafka-clients" % "3.6.1",
      "ch.qos.logback" % "logback-classic" % "1.4.14"
    ),
    assembly / mainClass := Some("com.store.streaming.Main")
  )

addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "2.1.5")
