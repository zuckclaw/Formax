// Backend menyimpan semua timestamp server sebagai naive UTC (datetime.utcnow)
// dan mengirimnya sebagai string ISO tanpa penanda zona (mis. "2026-08-12T14:53:24").
// `new Date(...)` memperlakukan string tanpa zona sebagai waktu LOKAL browser,
// sehingga di WIB semuanya bergeser -7 jam. Helper ini memaksanya dibaca sebagai UTC.
export function parseServerTime(str) {
  if (!str) return null;
  const s = String(str).trim().replace(' ', 'T');
  const hasZone = /(Z|[+-]\d{2}:?\d{2})$/i.test(s);
  const iso = hasZone ? s : `${s}Z`;
  const d = new Date(iso);
  return isNaN(d.getTime()) ? null : d;
}

export function formatDateFriendly(dateStr) {
  const d = parseServerTime(dateStr);
  if (!d) return null;
  try {
    return new Intl.DateTimeFormat('id-ID', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(d) + ' WIB';
  } catch {
    return d.toLocaleString('id-ID');
  }
}