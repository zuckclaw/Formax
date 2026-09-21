import { useCallback, useEffect, useState } from 'react';
import { getValidToken } from '../utils/authStorage';

function readAuthStatus() {
  try {
    return !!getValidToken();
  } catch {
    return false;
  }
}

/**
 * useAuthStatus — baca authentication state yang sebenarnya dipakai project.
 *
 * Source of truth SAMA seperti route guard (PrivateRoute/PublicRoute di App.jsx):
 * `getValidToken()` — sessionStorage dulu, lalu localStorage + cek expiry 30 hari.
 * Bukan flag "pernah buka halaman login", bukan flag remember-me.
 *
 * Benar saat:
 * - refresh / buka Home langsung via URL: state awal dihitung sinkron dari
 *   storage, jadi UI langsung benar sejak render pertama tanpa flicker.
 * - navigasi (Dashboard -> Home, /auth -> /dashboard): route berbeda me-mount
 *   ulang komponen, initializer di bawah membaca ulang token.
 *
 * Reaktif saat Home sudah terbuka lewat:
 * - login / register (setAuth dispatch 'auth:changed')
 * - logout (clearAuth dispatch 'auth:changed')
 * - session expired dari API (event 'auth:expired' dari api/config.js)
 * - perubahan antar-tab (event 'storage')
 * - kembali fokus / tab visible (re-cek token)
 */
export default function useAuthStatus() {
  const [isAuthenticated, setIsAuthenticated] = useState(readAuthStatus);

  const refresh = useCallback(() => {
    setIsAuthenticated(readAuthStatus());
  }, []);

  useEffect(() => {
    const onChange = () => refresh();
    const onVisibility = () => {
      if (document.visibilityState === 'visible') refresh();
    };
    globalThis.addEventListener('auth:changed', onChange);
    globalThis.addEventListener('auth:expired', onChange);
    globalThis.addEventListener('storage', onChange);
    globalThis.addEventListener('focus', onChange);
    document.addEventListener('visibilitychange', onVisibility);
    // NOTE: tidak perlu refresh() saat mount — initializer useState di atas
    // sudah membaca storage secara sinkron pada saat mount (selalu sesudah
    // setAuth/clearAuth + navigate pada semua alur login/logout).
    return () => {
      globalThis.removeEventListener('auth:changed', onChange);
      globalThis.removeEventListener('auth:expired', onChange);
      globalThis.removeEventListener('storage', onChange);
      globalThis.removeEventListener('focus', onChange);
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, [refresh]);

  return isAuthenticated;
}
