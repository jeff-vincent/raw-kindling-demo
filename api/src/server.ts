import express from "express";
import cors from "cors";
import { Pool } from "pg";
import Redis from "ioredis";
import { v4 as uuidv4 } from "uuid";

const app = express();
app.use(cors());
app.use(express.json());

// ── Database ────────────────────────────────────────────────────
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// ── Cache / pub-sub ─────────────────────────────────────────────
const redis = new Redis(process.env.REDIS_URL || "redis://localhost:6379");
const publisher = new Redis(process.env.REDIS_URL || "redis://localhost:6379");

// ── Routes ──────────────────────────────────────────────────────

app.get("/healthz", (_req, res) => {
  res.json({ status: "ok" });
});

app.get("/api/tasks", async (_req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM tasks ORDER BY created_at DESC"
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch tasks" });
  }
});

app.post("/api/tasks", async (req, res) => {
  const { title, description } = req.body;
  const id = uuidv4();
  try {
    const result = await pool.query(
      "INSERT INTO tasks (id, title, description, status) VALUES ($1, $2, $3, $4) RETURNING *",
      [id, title, description || "", "pending"]
    );
    const task = result.rows[0];

    // Publish event to Redis so the worker picks it up
    await publisher.publish(
      "task:created",
      JSON.stringify({ taskId: task.id, title: task.title })
    );

    // Invalidate cache
    await redis.del("tasks:summary");

    res.status(201).json(task);
  } catch (err) {
    res.status(500).json({ error: "Failed to create task" });
  }
});

app.patch("/api/tasks/:id/complete", async (req, res) => {
  try {
    const result = await pool.query(
      "UPDATE tasks SET status = 'completed', completed_at = NOW() WHERE id = $1 RETURNING *",
      [req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Task not found" });
    }
    await redis.del("tasks:summary");
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: "Failed to update task" });
  }
});

app.get("/api/tasks/summary", async (_req, res) => {
  // Try cache first
  const cached = await redis.get("tasks:summary");
  if (cached) {
    return res.json(JSON.parse(cached));
  }

  try {
    const total = await pool.query("SELECT COUNT(*) FROM tasks");
    const completed = await pool.query(
      "SELECT COUNT(*) FROM tasks WHERE status = 'completed'"
    );
    const pending = await pool.query(
      "SELECT COUNT(*) FROM tasks WHERE status = 'pending'"
    );

    const summary = {
      total: parseInt(total.rows[0].count),
      completed: parseInt(completed.rows[0].count),
      pending: parseInt(pending.rows[0].count),
    };

    await redis.set("tasks:summary", JSON.stringify(summary), "EX", 60);
    res.json(summary);
  } catch (err) {
    res.status(500).json({ error: "Failed to get summary" });
  }
});

// ── Init DB and start ───────────────────────────────────────────
async function initDB() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS tasks (
      id UUID PRIMARY KEY,
      title VARCHAR(255) NOT NULL,
      description TEXT DEFAULT '',
      status VARCHAR(50) DEFAULT 'pending',
      created_at TIMESTAMP DEFAULT NOW(),
      completed_at TIMESTAMP
    )
  `);
  console.log("✅ Database schema ready");
}

const PORT = parseInt(process.env.PORT || "3000");

initDB()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`🚀 Task API listening on :${PORT}`);
    });
  })
  .catch((err) => {
    console.error("❌ Failed to initialize:", err);
    process.exit(1);
  });
