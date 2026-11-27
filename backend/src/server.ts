import 'dotenv/config';
import express from 'express';
import cors from 'cors';

const app = express();
const allowedOrigin = process.env.ALLOWED_ORIGIN;
app.use(cors({ origin: allowedOrigin || '*', methods: ['GET','POST'], allowedHeaders: ['Authorization','Content-Type'] }));
app.use(express.json({ limit: '8mb' }));
const port = Number(process.env.PORT || 8787);
const apiToken = process.env.AI_GATEWAY_TOKEN;
const apiKey = process.env.AI_PROVIDER_API_KEY;
const base = (process.env.AI_PROVIDER_BASE_URL || 'https://api.openai.com/v1').replace(/\/$/, '');
const model = process.env.AI_PROVIDER_MODEL || '';

function protectedRoute(req: express.Request, res: express.Response, next: express.NextFunction) {
  if (!apiToken) return res.status(503).json({ error: 'Gateway token is not configured.' });
  if (req.header('Authorization') !== `Bearer ${apiToken}`) return res.status(401).json({ error: 'Unauthorized' });
  next();
}

app.get('/health', (_req, res) => res.json({ ok: true, service: 'AI personal gateway' }));
app.get('/v1/models', protectedRoute, (_req, res) => {
  if (!model) return res.status(503).json({ error: 'Provider model is not configured.' });
  res.json({ data: [{ id: model, object: 'model', owned_by: 'configured-provider' }] });
});

app.post('/v1/chat/completions', protectedRoute, async (req, res) => {
  if (!apiKey || !model) return res.status(503).json({ error: 'Provider is not configured on the gateway.' });
  const { messages, stream = true, model: requestedModel } = req.body ?? {};
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > 200) return res.status(400).json({ error: 'messages must be a non-empty array with at most 200 entries' });
  if (!messages.every((m: any) => m && typeof m.role === 'string' && typeof m.content === 'string' && m.role.length <= 32 && m.content.length <= 1_000_000)) {
    return res.status(400).json({ error: 'Each message must contain a valid role and text content.' });
  }
  const safeModel = typeof requestedModel === 'string' && requestedModel.trim() ? requestedModel.trim() : model;
  try {
    const upstream = await fetch(`${base}/chat/completions`, {
      method: 'POST', headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: safeModel, messages, stream: Boolean(stream) })
    });
    if (!upstream.ok) {
      const detail = await upstream.text();
      return res.status(upstream.status).json({ error: 'Provider error', detail: detail.slice(0, 4000) });
    }
    if (!stream) return res.status(200).json(await upstream.json());
    res.status(200); res.setHeader('Content-Type', 'text/event-stream'); res.setHeader('Cache-Control', 'no-cache, no-transform'); res.setHeader('Connection', 'keep-alive');
    if (!upstream.body) return res.end();
    const reader = upstream.body.getReader();
    let disconnected = false;
    res.on('close', () => { if (!res.writableEnded) { disconnected = true; void reader.cancel().catch(() => {}); } });
    while (!disconnected) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!res.write(value)) await new Promise<void>(resolve => res.once('drain', resolve));
    }
    if (!res.writableEnded) res.end();
  } catch (err) {
    console.error('Gateway request failed', err);
    if (!res.headersSent) res.status(502).json({ error: 'Provider request failed' }); else if (!res.writableEnded) res.end();
  }
});
app.listen(port, () => console.log(`AI gateway listening on :${port}`));
