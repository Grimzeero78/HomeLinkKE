// HomeLinkKE — API client + session state
const TOKEN_KEY = 'hl_token';
const state = {
  user: null,
  settings: { paybill_number: '0143374333', paybill_name: 'Isaac Bridget', gmaps_key: '' },
};

const token = {
  get: () => localStorage.getItem(TOKEN_KEY),
  set: t => { t ? localStorage.setItem(TOKEN_KEY, t) : localStorage.removeItem(TOKEN_KEY); },
};

async function api(path, opts = {}) {
  const headers = {};
  if (opts.body !== undefined) headers['Content-Type'] = 'application/json';
  const t = token.get();
  if (t) headers['Authorization'] = 'Bearer ' + t;
  let res;
  try {
    res = await fetch('/api' + path, {
      method: opts.method || (opts.body !== undefined ? 'POST' : 'GET'),
      headers,
      body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
    });
  } catch (e) {
    return { ok: false, error: 'No internet connection' };
  }
  let data;
  try { data = await res.json(); } catch (e) { data = { ok: false, error: 'Server error (' + res.status + ')' }; }
  if (res.status === 401 && token.get()) { token.set(null); state.user = null; }
  return data;
}

// client-side image compression → data URL (WebP with JPEG fallback)
function compressImage(file, maxDim, quality) {
  return new Promise((resolve, reject) => {
    const fr = new FileReader();
    fr.onerror = () => reject(new Error('Could not read file'));
    fr.onload = () => {
      const img = new Image();
      img.onerror = () => reject(new Error('Could not load image'));
      img.onload = () => {
        let { width: w, height: h } = img;
        const scale = Math.min(1, maxDim / Math.max(w, h));
        w = Math.round(w * scale); h = Math.round(h * scale);
        const cv = document.createElement('canvas');
        cv.width = w; cv.height = h;
        cv.getContext('2d').drawImage(img, 0, 0, w, h);
        let out = cv.toDataURL('image/webp', quality);
        if (!out.startsWith('data:image/webp')) out = cv.toDataURL('image/jpeg', quality);
        resolve(out);
      };
      img.src = fr.result;
    };
    fr.readAsDataURL(file);
  });
}

async function compressTo(file, maxKB, maxDim = 1200, q = 0.72) {
  let out = await compressImage(file, maxDim, q);
  let cur = maxDim, curQ = q;
  while (out.length > maxKB * 1400 && curQ > 0.4) { // data URL ≈ 1.4x binary size
    curQ -= 0.12;
    out = await compressImage(file, cur, curQ);
    if (curQ <= 0.42) { cur = Math.round(cur * 0.85); }
  }
  return out;
}

// make a small card thumbnail out of an existing image data URL (no re-reading files).
// Cards/list/map embed thumbs — keeps a 60-listing page around ~1 MB instead of 6-9 MB.
function shrinkDataUrl(src, maxDim = 340, q = 0.6) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      try {
        const scale = Math.min(1, maxDim / Math.max(img.width, img.height));
        const cv = document.createElement('canvas');
        cv.width = Math.max(1, Math.round(img.width * scale));
        cv.height = Math.max(1, Math.round(img.height * scale));
        cv.getContext('2d').drawImage(img, 0, 0, cv.width, cv.height);
        resolve(cv.toDataURL('image/webp', q));
      } catch (e) { reject(e); }
    };
    img.onerror = () => reject(new Error('Could not load image'));
    img.src = src;
  });
}
