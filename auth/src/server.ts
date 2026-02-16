import express from 'express';
import cors from 'cors';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import Redis from 'ioredis';

const app = express();
app.use(cors());
app.use(express.json());

const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
});

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-production';
const PORT = parseInt(process.env.PORT || '3001');

interface User {
  id: string;
  email: string;
  passwordHash: string;
}

const users: Map<string, User> = new Map();

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'auth' });
});

app.post('/register', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password required' });
  }
  if (users.has(email)) {
    return res.status(409).json({ error: 'user already exists' });
  }
  const passwordHash = await bcrypt.hash(password, 10);
  const id = crypto.randomUUID();
  users.set(email, { id, email, passwordHash });
  const token = jwt.sign({ sub: id, email }, JWT_SECRET, { expiresIn: '24h' });
  await redis.setex(`session:${id}`, 86400, JSON.stringify({ email }));
  res.status(201).json({ token, userId: id });
});

app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const user = users.get(email);
  if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
    return res.status(401).json({ error: 'invalid credentials' });
  }
  const token = jwt.sign({ sub: user.id, email }, JWT_SECRET, { expiresIn: '24h' });
  await redis.setex(`session:${user.id}`, 86400, JSON.stringify({ email }));
  res.json({ token, userId: user.id });
});

app.get('/verify', async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'missing token' });
  }
  try {
    const payload = jwt.verify(authHeader.slice(7), JWT_SECRET) as { sub: string; email: string };
    const session = await redis.get(`session:${payload.sub}`);
    if (!session) {
      return res.status(401).json({ error: 'session expired' });
    }
    res.json({ userId: payload.sub, email: payload.email });
  } catch {
    res.status(401).json({ error: 'invalid token' });
  }
});

app.listen(PORT, () => {
  console.log(`Auth service listening on :${PORT}`);
});
