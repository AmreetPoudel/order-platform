const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");
const { createClient } = require("redis");
const amqp = require("amqplib");

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 4000;
const CACHE_KEY = "posts:all";
const CACHE_TTL_SECONDS = 30;

// --- Postgres pool (used for reads / cache misses) ---
const pool = new Pool({
  host: process.env.PGHOST || "postgres",
  port: process.env.PGPORT || 5432,
  user: process.env.PGUSER || "postgres",
  password: process.env.PGPASSWORD || "postgres",
  database: process.env.PGDATABASE || "postsdb",
});

// --- Redis client (cache) ---
const redisClient = createClient({
  url: `redis://${process.env.REDIS_HOST || "redis"}:${process.env.REDIS_PORT || 6379}`,
});
redisClient.on("error", (err) => console.error("Redis error:", err));

// --- RabbitMQ connection (queue producer) ---
let channel;
async function connectQueue() {
  const rabbitUrl = `amqp://${process.env.RABBITMQ_HOST || "rabbitmq"}:5672`;
  // retry loop - rabbitmq container may take a few seconds to be ready
  for (let i = 0; i < 10; i++) {
    try {
      const conn = await amqp.connect(rabbitUrl);
      channel = await conn.createChannel();
      await channel.assertQueue("posts_queue", { durable: true });
      console.log("Connected to RabbitMQ");
      return;
    } catch (err) {
      console.log("RabbitMQ not ready, retrying in 3s...");
      await new Promise((r) => setTimeout(r, 3000));
    }
  }
  throw new Error("Could not connect to RabbitMQ after retries");
}

async function start() {
  await redisClient.connect();
  await connectQueue();

  app.get("/health", (req, res) => res.json({ status: "ok" }));

  // GET all posts - cache-first
  app.get("/api/posts", async (req, res) => {
    try {
      const cached = await redisClient.get(CACHE_KEY);
      if (cached) {
        return res.json({ source: "cache", posts: JSON.parse(cached) });
      }
      const result = await pool.query(
        "SELECT * FROM posts ORDER BY created_at DESC"
      );
      await redisClient.setEx(CACHE_KEY, CACHE_TTL_SECONDS, JSON.stringify(result.rows));
      res.json({ source: "db", posts: result.rows });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: "Failed to fetch posts" });
    }
  });

  // GET search posts - always hits DB directly (search results aren't cached)
  app.get("/api/posts/search", async (req, res) => {
    const q = req.query.q || "";
    try {
      const result = await pool.query(
        "SELECT * FROM posts WHERE title ILIKE $1 OR content ILIKE $1 ORDER BY created_at DESC",
        [`%${q}%`]
      );
      res.json({ posts: result.rows });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: "Search failed" });
    }
  });

  // POST create a post - does NOT touch DB directly, publishes to queue instead
  app.post("/api/posts", async (req, res) => {
    const { title, content } = req.body;
    if (!title || !content) {
      return res.status(400).json({ error: "title and content are required" });
    }
    try {
      const message = JSON.stringify({ title, content });
      channel.sendToQueue("posts_queue", Buffer.from(message), { persistent: true });
      res.status(202).json({ status: "queued", title, content });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: "Failed to queue post" });
    }
  });

  app.listen(PORT, () => console.log(`API listening on port ${PORT}`));
}

start().catch((err) => {
  console.error("Failed to start API:", err);
  process.exit(1);
});
