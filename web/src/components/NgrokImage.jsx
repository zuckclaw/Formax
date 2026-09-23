import { useEffect, useState } from 'react';
import { apiFetch } from '../api/config';
import { normalizeFileUrl } from '../utils/normalizeFileUrl';

export default function NgrokImage({ src, alt, className, style, onError, loading = 'lazy', decoding = 'async', draggable = false }) {
  const [blobUrl, setBlobUrl] = useState(null);
  const [failed, setFailed] = useState(false);

  const cleanSrc = normalizeFileUrl((src || '').trim());
  const isNgrok = cleanSrc.includes('ngrok-free.dev') || cleanSrc.includes('ngrok-free.app');

  useEffect(() => {
    if (!cleanSrc || !isNgrok) {
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
        // Validasi blob adalah image, bukan HTML warning ngrok
        if (blob.type && blob.type.startsWith('text/html')) {
          throw new Error('Ngrok returned HTML (check header)');
        }
        objectUrl = URL.createObjectURL(blob);
        setBlobUrl(objectUrl);
      })
      .catch((err) => {
        if (cancelled || err.name === 'AbortError') return;
        console.error('[NgrokImage] gagal load:', cleanSrc, err);
        setFailed(true);
        if (onError) onError(err);
      });

    return () => {
      cancelled = true;
      controller.abort();
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [cleanSrc, isNgrok]);

  // Gagal total -> jangan render apa-apa (parent bisa show placeholder)
  if (failed) {
    return null;
  }

  // Ngrok + blob ready -> pakai blob URL (sudah bypass ORB)
  if (isNgrok && blobUrl) {
    return <img src={blobUrl} alt={alt} className={className} style={style} onError={onError} loading={loading} decoding={decoding} draggable={draggable} />;
  }

  // Ngrok tapi masih loading -> render sizer/loading
  if (isNgrok && !blobUrl) {
    return (
      <div
        className={className}
        style={{
          ...style,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: '#f1f5f9',
          color: '#94a3b8',
          fontSize: '12px',
          minHeight: style?.minHeight || '120px',
        }}
      >
        Memuat banner...
      </div>
    );
  }

  // Non-ngrok -> direct <img>
  return <img src={cleanSrc} alt={alt} className={className} style={style} onError={onError} loading={loading} decoding={decoding} draggable={draggable} />;
}
