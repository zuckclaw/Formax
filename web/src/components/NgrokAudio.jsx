import { useEffect, useState } from 'react';
import { apiFetch } from '../api/config';

// Komponen <audio> yang aman untuk ngrok-free.dev
// Mirror dari NgrokImage.jsx — bypass OpaqueResponseBlocking via fetch + blob URL
// preload="metadata" hemat (tidak download full sampai user play)
export default function NgrokAudio({ src, style, controls = true, preload = 'metadata', className }) {
  const [blobUrl, setBlobUrl] = useState(null);
  const [failed, setFailed] = useState(false);

  const cleanSrc = (src || '').trim();
  const isNgrok = cleanSrc.includes('ngrok-free.dev') || cleanSrc.includes('ngrok-free.app');
  const isDataAudio = cleanSrc.startsWith('data:audio/') || cleanSrc.startsWith('data:video/');
  const shouldFetch = isNgrok && !isDataAudio;

  useEffect(() => {
    if (!cleanSrc || !shouldFetch) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setBlobUrl(null);
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setFailed(false);
      return;
    }

    let objectUrl = null;
    let cancelled = false;
    const controller = new AbortController();

    apiFetch(cleanSrc, { signal: controller.signal })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.blob();
      })
      .then((blob) => {
        if (cancelled) return;
        // Ngrok warning page dibalikin sebagai text/html — bukan audio
        if (blob.type && blob.type.startsWith('text/html')) {
          throw new Error('Ngrok returned HTML (check header)');
        }
        objectUrl = URL.createObjectURL(blob);
        setBlobUrl(objectUrl);
      })
      .catch((err) => {
        if (cancelled || err.name === 'AbortError') return;
        console.error('[NgrokAudio] gagal load:', cleanSrc, err);
        setFailed(true);
      });

    return () => {
      cancelled = true;
      controller.abort();
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [cleanSrc, shouldFetch]);

  // Gagal total -> fallback ke src asli biar browser coba direct (mungkin bukan ngrok)
  if (failed) {
    return <audio src={cleanSrc} controls={controls} preload={preload} style={style} className={className} />;
  }

  // Ngrok + blob ready -> pakai blob URL
  if (shouldFetch && blobUrl) {
    return <audio src={blobUrl} controls={controls} preload={preload} style={style} className={className} />;
  }

  // Ngrok tapi masih loading -> placeholder hemat
  if (shouldFetch && !blobUrl) {
    return (
      <div
        style={{
          ...style,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: '#f1f5f9',
          color: '#94a3b8',
          fontSize: '12px',
          minHeight: '48px',
          borderRadius: '8px',
          padding: '8px',
        }}
        className={className}
      >
        Memuat audio...
      </div>
    );
  }

  // Non-ngrok / data:audio -> direct <audio>
  return <audio src={cleanSrc} controls={controls} preload={preload} style={style} className={className} />;
}
