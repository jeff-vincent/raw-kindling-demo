require "sinatra"
require "sinatra/json"
require "redis"
require "bunny"
require "json"

set :port, ENV.fetch("PORT", 3005).to_i
set :bind, "0.0.0.0"

redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379"))

Thread.new do
  begin
    conn = Bunny.new(
      host: ENV.fetch("RABBITMQ_HOST", "localhost"),
      port: ENV.fetch("RABBITMQ_PORT", 5672).to_i,
      user: ENV.fetch("RABBITMQ_USER", "guest"),
      password: ENV.fetch("RABBITMQ_PASSWORD", "guest")
    )
    conn.start
    ch = conn.create_channel
    queue = ch.queue("notifications.send", durable: true)

    puts "Listening for notification events..."
    queue.subscribe(block: false) do |_delivery, _properties, body|
      event = JSON.parse(body)
      notification_id = SecureRandom.uuid
      redis.lpush("notifications:#{event['user_id']}", JSON.dump({
        id: notification_id,
        type: event["type"],
        message: event["message"],
        timestamp: Time.now.utc.iso8601
      }))
      puts "Notification #{notification_id} stored for user #{event['user_id']}"
    end
  rescue => e
    puts "RabbitMQ connection error: #{e.message}"
  end
end

get "/health" do
  json status: "ok", service: "notifications"
end

get "/notifications/:user_id" do
  user_id = params[:user_id]
  raw = redis.lrange("notifications:#{user_id}", 0, 49)
  notifications = raw.map { |n| JSON.parse(n) }
  json notifications
end

post "/notifications" do
  body = JSON.parse(request.body.read)
  notification_id = SecureRandom.uuid
  redis.lpush("notifications:#{body['user_id']}", JSON.dump({
    id: notification_id,
    type: body["type"],
    message: body["message"],
    timestamp: Time.now.utc.iso8601
  }))
  status 201
  json id: notification_id
end
