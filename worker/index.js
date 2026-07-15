const { Pool } = require("pg");
const { createClient } = require("redis");
const amqp = require("amqplib");

const CACHE_KEY = "posts:all";

const pool = new Pool({
  host: process.env.PGHOST || "postgres",
  port: process.env.PGPORT || 5432,
  user: process.env.PGUSER || "postgres",
  password: process.env.PGPASSWORD || "postgres",
  database: process.env.PGDATABASE || "postsdb",
});

const redisClient = createClient({
  url: `redis://${process.env.REDIS_HOST || "redis"}:${process.env.REDIS_PORT || 6379}`,
});
redisClient.on("error", (err) => console.error("Redis error:", err));

async function connectQueue() {
  const rabbitUrl = `amqp://${process.env.RABBITMQ_HOST || "rabbitmq"}:5672`;
  for (let i = 0; i < 10; i++) {
    try {
      const conn = await amqp.connect(rabbitUrl);
      const channel = await conn.createChannel();
      await channel.assertQueue("posts_queue", { durable: true });
      console.log("Worker connected to RabbitMQ");
      return channel;
    } catch (err) {
      console.log("RabbitMQ not ready, retrying in 3s...");
      await new Promise((r) => setTimeout(r, 3000));
    }
  }
  throw new Error("Could not connect to RabbitMQ after retries");
}

async function start() {
  await redisClient.connect();
  const channel = await connectQueue();
  channel.prefetch(1); // process one message at a time

  console.log("Worker waiting for messages on posts_queue...");

  channel.consume("posts_queue", async (msg) => {
    if (!msg) return;
    try {
      const { title, content } = JSON.parse(msg.content.toString());
      await pool.query(
        "INSERT INTO posts (title, content) VALUES ($1, $2)",
        [title, content]
      );
      // cache is now stale - remove it so next read rebuilds from DB
      await redisClient.del(CACHE_KEY);
      console.log(`Saved post: ${title}`);
      channel.ack(msg);
    } catch (err) {
      console.error("Failed to process message:", err);
      channel.nack(msg, false, false); // drop bad message, don't requeue forever
    }
  });
}

start().catch((err) => {
  console.error("Worker failed to start:", err);
  process.exit(1);
});
