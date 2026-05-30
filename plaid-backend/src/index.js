const PLAID_BASE = 'https://sandbox.plaid.com';

async function plaid(path, body, env) {
  return fetch(`${PLAID_BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: env.PLAID_CLIENT_ID,
      secret: env.PLAID_SECRET,
      ...body,
    }),
  });
}

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });

    const path = new URL(request.url).pathname;

    try {
      if (path === '/create_link_token') {
        const res = await plaid('/link/token/create', {
          client_name: 'Finance 101',
          country_codes: ['US'],
          language: 'en',
          user: { client_user_id: 'finance101-user' },
          products: ['transactions'],
        }, env);
        return new Response(await res.text(), { headers: cors });
      }

      if (path === '/exchange_public_token') {
        const { public_token } = await request.json();
        const res = await plaid('/item/public_token/exchange', { public_token }, env);
        return new Response(await res.text(), { headers: cors });
      }

      if (path === '/transactions') {
        const { access_token, start_date, end_date } = await request.json();
        const today = new Date();
        const thirtyDaysAgo = new Date(today - 30 * 24 * 60 * 60 * 1000);
        const fmt = (d) => d.toISOString().split('T')[0];
        const res = await plaid('/transactions/get', {
          access_token,
          start_date: start_date ?? fmt(thirtyDaysAgo),
          end_date: end_date ?? fmt(today),
          options: { count: 250, offset: 0 },
        }, env);
        return new Response(await res.text(), { headers: cors });
      }

      if (path === '/accounts') {
        const { access_token } = await request.json();
        const res = await plaid('/accounts/get', { access_token }, env);
        return new Response(await res.text(), { headers: cors });
      }

      return new Response(JSON.stringify({ error: 'Not found' }), { status: 404, headers: cors });
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: cors });
    }
  },
};
