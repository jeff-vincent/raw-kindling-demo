package com.store.streaming

import akka.actor.typed.ActorSystem
import akka.actor.typed.scaladsl.Behaviors
import akka.http.scaladsl.Http
import akka.http.scaladsl.marshallers.sprayjson.SprayJsonSupport._
import akka.http.scaladsl.server.Directives._
import spray.json.DefaultJsonProtocol._
import org.apache.kafka.clients.producer.{KafkaProducer, ProducerConfig, ProducerRecord}
import org.apache.kafka.clients.consumer.{KafkaConsumer, ConsumerConfig}
import java.util.Properties
import java.time.Duration
import scala.jdk.CollectionConverters._

object Main {
  implicit val system: ActorSystem[Nothing] = ActorSystem(Behaviors.empty, "streaming")
  implicit val ec = system.executionContext

  val kafkaBootstrap: String = sys.env.getOrElse("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
  val port: Int = sys.env.getOrElse("PORT", "3009").toInt

  def createProducer(): KafkaProducer[String, String] = {
    val props = new Properties()
    props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaBootstrap)
    props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer")
    props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer")
    new KafkaProducer[String, String](props)
  }

  case class Event(topic: String, key: String, value: String)
  implicit val eventFormat = jsonFormat3(Event)

  def main(args: Array[String]): Unit = {
    val producer = createProducer()

    val route = concat(
      path("health") {
        get {
          complete(Map("status" -> "ok", "service" -> "streaming"))
        }
      },
      path("publish") {
        post {
          entity(as[Event]) { event =>
            val record = new ProducerRecord[String, String](event.topic, event.key, event.value)
            producer.send(record)
            complete(Map("published" -> "true", "topic" -> event.topic))
          }
        }
      },
      path("topics") {
        get {
          complete(Map("kafka_bootstrap" -> kafkaBootstrap, "status" -> "connected"))
        }
      }
    )

    Http().newServerAt("0.0.0.0", port).bind(route)
    println(s"Streaming service listening on :$port")
  }
}
