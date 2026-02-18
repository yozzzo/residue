import { Hono } from 'hono';
import { cors } from 'hono/cors';
import type { Env } from './types/env';
import { worldsRoutes } from './routes/worlds';
import { enemiesRoutes } from './routes/enemies';
import { jobsRoutes } from './routes/jobs';
import { runsRoutes } from './routes/runs';
import { turnsRoutes } from './routes/turns';

const app = new Hono<{ Bindings: Env }>();

app.use('*', cors({
  origin: '*',
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
}));

app.get('/api/health', (c) => {
  return c.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.route('/api/v1', worldsRoutes);
app.route('/api/v1', enemiesRoutes);
app.route('/api/v1', jobsRoutes);
app.route('/api/v1', runsRoutes);
app.route('/api/v1', turnsRoutes);

app.notFound((c) => c.json({ error: 'Not Found' }, 404));

app.onError((err, c) => {
  console.error('Unhandled error:', err);
  return c.json({ error: 'Internal Server Error' }, 500);
});

export default app;
