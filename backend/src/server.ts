import 'dotenv/config';
import express from 'express';
import cors from 'cors';

const app = express();
const allowedOrigin = process.env.ALLOWED_ORIGIN;
app.use(cors({
  origin: (origin, callback) => {
    // Native clients do not send Origin. Browser origins must be explicitly configured.
    if (!origin || (allowedOrigin && origin === allowedOrigin)) return callback(null, true);
    return callback(new Error('Origin not allowed'));
  },
  methods: ['GET','POST'],
  allowedHeaders: ['Authorization','Content-Type']
}));
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
  if (typeof stream !== 'boolean') return res.status(400).json({ error: 'stream must be a boolean.' });
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > 200) return res.status(400).json({ error: 'messages must be a non-empty array with at most 200 entries' });
  if (!messages.every((m: any) => m && ['system','user','assistant','tool'].includes(m.role) && typeof m.content === 'string' && m.content.length <= 1_000_000)) {
    return res.status(400).json({ error: 'Each message must contain an allowed role and text content.' });
  }
  const totalContentLength = messages.reduce((total: number, m: any) => total + m.content.length, 0);
  if (totalContentLength > 4_000_000) return res.status(413).json({ error: 'Total message content exceeds 4 MB.' });
  const safeModel = typeof requestedModel === 'string' && requestedModel.trim() ? requestedModel.trim() : model;
  if (safeModel !== model) return res.status(400).json({ error: 'Requested model is not enabled on this gateway.' });

  const controller = new AbortController();
  let clientDisconnected = false;
  let inactivityTimer: ReturnType<typeof setTimeout> | undefined;
  const clearInactivityTimer = () => { if (inactivityTimer) clearTimeout(inactivityTimer); inactivityTimer = undefined; };
  const armInactivityTimer = (timeoutMs: number) => {
    clearInactivityTimer();
    inactivityTimer = setTimeout(() => controller.abort(), timeoutMs);
  };
  res.on('close', () => {
    if (!res.writableEnded) {
      clientDisconnected = true;
      controller.abort();
      clearInactivityTimer();
    }
  });

  try {
    // Non-streaming calls are bounded; streaming uses a renewable inactivity deadline.
    // Bound the wait for upstream headers for both modes.\n    armInactivityTimer(90_000);
    const upstream = await fetch(`${base}/chat/completions`, {
      method: 'POST', headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: safeModel, messages, stream }),
      signal: controller.signal
    });
    if (!upstream.ok) {
      clearInactivityTimer();
      await upstream.text(); // Consume the body without exposing provider diagnostics or secrets to the client.
      if (!clientDisconnected) return res.status(upstream.status).json({ error: 'Provider request was rejected or failed.' });
      return;
    }
    if (!stream) {
      try { const payload = await upstream.json(); clearInactivityTimer(); return res.status(200).json(payload); }
      catch (err) { clearInactivityTimer(); throw err; }
    }
    clearInactivityTimer();
    res.status(200); res.setHeader('Content-Type', 'text/event-stream'); res.setHeader('Cache-Control', 'no-cache, no-transform'); res.setHeader('Connection', 'keep-alive');
    if (!upstream.body) return res.end();
    const reader = upstream.body.getReader();
    armInactivityTimer(120_000);
    while (!clientDisconnected) {
      const { done, value } = await reader.read();
      if (done) break;
      armInactivityTimer(120_000);
      if (!res.write(value)) {
        await new Promise<void>((resolve, reject) => {
          const cleanup = () => { res.off('drain', onDrain); res.off('close', onClose); };
          const onDrain = () => { cleanup(); resolve(); };
          const onClose = () => { cleanup(); resolve(); };
          res.once('drain', onDrain);
          res.once('close', onClose);
        });
      }
    }
    clearInactivityTimer();
    if (!res.writableEnded && !clientDisconnected) res.end();
  } catch (err) {
    clearInactivityTimer();
    if (clientDisconnected) return;
    if (controller.signal.aborted) {
      if (!res.headersSent) res.status(504).json({ error: 'Provider request timed out.' }); else if (!res.writableEnded) res.end();
      return;
    }
    console.error('Gateway request failed', err);
    if (!res.headersSent) res.status(502).json({ error: 'Provider request failed' }); else if (!res.writableEnded) res.end();
  }
});
app.listen(port, () => console.log(`AI gateway listening on :${port}`));
