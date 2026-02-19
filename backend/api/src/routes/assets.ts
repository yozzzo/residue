import { Hono } from 'hono';
import type { Env } from '../types/env';

const assetsRoutes = new Hono<{ Bindings: Env }>();

// GET /assets/manifest - Return asset manifest from R2
assetsRoutes.get('/assets/manifest', async (c) => {
  try {
    const object = await c.env.ASSETS.get('manifest.json');
    if (!object) {
      return c.json({ version: '0.0.0', assets: [] });
    }
    const manifest = await object.text();
    c.header('Cache-Control', 'public, max-age=300'); // 5 min cache
    return c.json(JSON.parse(manifest));
  } catch (err) {
    console.error('Failed to fetch manifest:', err);
    return c.json({ version: '0.0.0', assets: [] });
  }
});

// GET /assets/file/:path+ - Serve asset file from R2
assetsRoutes.get('/assets/file/*', async (c) => {
  const path = c.req.path.replace('/api/v1/assets/file/', '');
  if (!path) {
    return c.json({ error: 'Missing path' }, 400);
  }

  try {
    const object = await c.env.ASSETS.get('assets/' + path);
    if (!object) {
      return c.json({ error: 'Not found' }, 404);
    }

    const headers = new Headers();
    headers.set('Cache-Control', 'public, max-age=86400'); // 24h cache
    if (path.endsWith('.png')) headers.set('Content-Type', 'image/png');
    else if (path.endsWith('.ogg')) headers.set('Content-Type', 'audio/ogg');
    else if (path.endsWith('.jpg') || path.endsWith('.jpeg')) headers.set('Content-Type', 'image/jpeg');
    else headers.set('Content-Type', 'application/octet-stream');

    return new Response(object.body, { headers });
  } catch (err) {
    console.error('Failed to serve asset:', err);
    return c.json({ error: 'Internal error' }, 500);
  }
});

export { assetsRoutes };
