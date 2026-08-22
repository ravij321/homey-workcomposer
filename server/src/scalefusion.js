const DEFAULT_BASE_URL = 'https://api.scalefusion.com';

function getConfig() {
  const token = process.env.SCALEFUSION_API_TOKEN;
  if (!token) throw new Error('SCALEFUSION_API_TOKEN is not configured');
  return {
    baseUrl: (process.env.SCALEFUSION_API_URL || DEFAULT_BASE_URL).replace(/\/$/, ''),
    token,
  };
}

export async function listScalefusionDevices({ cursor } = {}) {
  const { baseUrl, token } = getConfig();
  const url = new URL(`${baseUrl}/api/v3/devices.json`);
  if (cursor) url.searchParams.set('cursor', cursor);
  const response = await fetch(url, {
    headers: { Authorization: token, Accept: 'application/json' },
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Scalefusion API ${response.status}: ${body.slice(0, 500)}`);
  }
  return response.json();
}

export async function getScalefusionDevice(id) {
  const { baseUrl, token } = getConfig();
  const response = await fetch(`${baseUrl}/api/v3/devices/${encodeURIComponent(id)}.json`, {
    headers: { Authorization: token, Accept: 'application/json' },
  });
  if (!response.ok) throw new Error(`Scalefusion API ${response.status}`);
  return response.json();
}
