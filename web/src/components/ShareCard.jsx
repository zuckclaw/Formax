import NgrokImage from './NgrokImage'

export default function ShareCard({
  variant = 'top',
  link,
  qrUrl,
  copied,
  hasId,
  onCopy,
  onViewQr,
  onGenerate,
}) {
  const cls = `fb-share-card fb-share-card--${variant}`

  if (!hasId) {
    return (
      <div className={cls}>
        <div className="fb-share-info">
          <h3 className="fb-share-title">Bagikan Form</h3>
          <p className="fb-share-desc">Simpan form terlebih dahulu untuk mendapatkan link &amp; QR code.</p>
        </div>
      </div>
    )
  }

  return (
    <div className={cls}>
      <button
        type="button"
        className="fb-share-thumb"
        onClick={qrUrl ? onViewQr : onGenerate}
        title={qrUrl ? 'Lihat QR code' : 'Generate QR code'}
      >
        {qrUrl ? (
          <NgrokImage src={qrUrl} alt="QR Code Form" className="fb-share-thumb-img" />
        ) : (
          <span className="fb-share-thumb-empty">QR</span>
        )}
      </button>
      <div className="fb-share-info">
        <h3 className="fb-share-title">Bagikan Form</h3>
        <p className="fb-share-link" title={link}>{link}</p>
        <div className="fb-share-actions">
          <button type="button" className="fb-share-btn primary" onClick={onCopy}>
            {copied ? 'Tersalin!' : 'Salin Link'}
          </button>
          {qrUrl ? (
            <button type="button" className="fb-share-btn secondary" onClick={onViewQr}>
              Lihat QR
            </button>
          ) : (
            <button type="button" className="fb-share-btn secondary" onClick={onGenerate}>
              Generate QR
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
