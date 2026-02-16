import Redis from "ioredis";
import { Pool } from "pg";

// ── Connections ─────────────────────────────────────────────────
const subscriber = new Redis(process.env.REDIS_URL || "redis://localhost:6379");
const redis = new Redis(process.env.REDIS_URL || "redis://localhost:6379");
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// ── Event handlers ──────────────────────────────────────────────

async function handleTaskCreated(data: { taskId: string; title: string }) {
  console.log(`📋 Processing new task: ${data.title} (${data.taskId})`);

  // Simulate enrichment — in a real app this might call an external API,
  // run NLP classification, send a notification, etc.
  await new Promise((resolve) => setTimeout(resolve, 500));

  // Update task with processing metadata
  await pool.query(
    "UPDATE tasks SET description = description || $1 WHERE id = $2",
    ["\n[worker] Processed at " + new Date().toISOString(), data.taskId]
  );

  // Increment processed counter in Redis
  await redis.incr("stats:tasks_processed");

  console.log(`✅ Task ${data.taskId} processed`);
}

// ── Subscriber loop ─────────────────────────────────────────────

async function main() {
  console.log("🔧 Task worker starting...");
  console.log(`   REDIS_URL: ${process.env.REDIS_URL || "(default)"}`);
  console.log(`   DATABASE_URL: ${process.env.DATABASE_URL ? "(set)" : "(not set)"}`);

  subscriber.subscribe("task:created", (err) => {
    if (err) {
      console.error("❌ Failed to subscribe:", err);
      process.exit(1);
    }
    console.log("📡 Subscribed to task:created channel");
  });

  subscriber.on("message", async (channel, message) => {
    if (channel === "task:created") {
      try {
        const data = JSON.parse(message);
        await handleTaskCreated(data);
      } catch (err) {
        console.error("❌ Error processing message:", err);
      }
    }
  });

  // Graceful shutdown
  process.on("SIGTERM", async () => {
    console.log("🛑 Shutting down worker...");
    await subscriber.unsubscribe("task:created");
    await subscriber.quit();
    await redis.quit();
    await pool.end();
    process.exit(0);
  });
}

main().catch((err) => {
  console.error("❌ Worker failed to start:", err);
  process.exit(1);
});
