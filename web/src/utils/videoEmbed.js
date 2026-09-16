// Utility video embed: YouTube, Vimeo, Google Drive, MP4 direct
// Simpan sebagai <div class="video-embed" data-video="..."> agar lolos sanitizer backend
// Frontend enhance jadi iframe/video saat render

export function parseVideoUrl(raw) {
  if (!raw || typeof raw !== 'string') return null
  let url = raw.trim()
  if (!url || url === 'undefined' || url === 'null') return null

  // Normalisasi skema jika user paste tanpa protocol (mis. www.youtube.com atau youtu.be)
  if (/^(www\.|youtube\.com|youtu\.be|vimeo\.com|player\.vimeo\.com|drive\.google\.com)/i.test(url)) {
    url = `https://${url}`
  }

  // 1) YouTube parser (menangani watch?v=, watch?feature=...&v=, youtu.be/, shorts/, embed/, live/, dll)
  try {
    const u = new URL(url)
    const host = u.hostname.toLowerCase().replace(/^www\./, '')
    if (host === 'youtube.com' || host === 'm.youtube.com' || host === 'youtube-nocookie.com' || host === 'youtu.be') {
      let id = null
      if (host === 'youtu.be') {
        id = u.pathname.replace(/^\/+/, '').split('/')[0].split('?')[0]
      } else {
        id = u.searchParams.get('v')
        if (!id) {
          const pathMatch = u.pathname.match(/\/(?:embed|shorts|live|v)\/([a-zA-Z0-9_-]{6,15})/i)
          if (pathMatch) id = pathMatch[1]
        }
      }
      if (id && id !== 'undefined' && id !== 'null') {
        // preserve start time jika ada (t=30s atau t=30)
        let t = u.searchParams.get('t') || u.searchParams.get('start')
        let embedUrl = `https://www.youtube.com/embed/${id}`
        if (t) {
          const sec = parseInt(t, 10)
          if (!isNaN(sec) && sec > 0) embedUrl += `?start=${sec}`
        }
        return { type: 'youtube', id, embedUrl, original: url }
      }
    }
  } catch {
    // Fallback regex jika URL tidak bisa di-parse lewat constructor URL
    const ytRegex = /(?:youtube\.com\/(?:watch\?.*?v=|embed\/|shorts\/|live\/)|youtu\.be\/)([a-zA-Z0-9_-]{6,15})/i
    const ytMatch = url.match(ytRegex)
    if (ytMatch && ytMatch[1] && ytMatch[1] !== 'undefined') {
      const id = ytMatch[1]
      return { type: 'youtube', id, embedUrl: `https://www.youtube.com/embed/${id}`, original: url }
    }
  }

  // 2) Vimeo: https://vimeo.com/123456789 atau player.vimeo.com/video/123
  const vimeoRegex = /(?:vimeo\.com\/(?:video\/)?)(\d{6,})/i
  const vm = url.match(vimeoRegex)
  if (vm && vm[1]) {
    const id = vm[1]
    return { type: 'vimeo', id, embedUrl: `https://player.vimeo.com/video/${id}`, original: url }
  }

  // 3) Google Drive: drive.google.com/file/d/FILEID/view atau open?id=FILEID atau file/d/FILEID/preview
  const driveIdMatch = url.match(/drive\.google\.com\/(?:file\/d\/|open\?id=)([a-zA-Z0-9_-]{10,})/i)
  if (driveIdMatch && driveIdMatch[1]) {
    const id = driveIdMatch[1]
    return { type: 'drive', id, embedUrl: `https://drive.google.com/file/d/${id}/preview`, original: url }
  }

  // 4) Direct video file: .mp4 .webm .ogg .mov (case insensitive, allow querystring)
  const isDirect = /\.(mp4|webm|ogg|mov)(\?.*)?$/i.test(url)
  if (isDirect) {
    if (/^https?:\/\//i.test(url) || url.startsWith('/') || url.startsWith('data:video/')) {
      return { type: 'mp4', id: url, embedUrl: url, original: url }
    }
  }
  return null
}

export function isVideoUrl(url) {
  return !!parseVideoUrl(url)
}

export function getEmbedInfo(url) {
  return parseVideoUrl(url)
}

// Create HTML string for storage (sanitizer-safe)
export function createVideoEmbedHtml(rawUrl) {
  const parsed = parseVideoUrl(rawUrl)
  if (!parsed) return null
  const safeUrl = escapeAttr(parsed.original.trim())
  const safeEmbed = escapeAttr(parsed.embedUrl)
  const safeType = escapeAttr(parsed.type)
  // placeholder div - will be enhanced to iframe/video client side
  return `<div class="video-embed" data-video="${safeUrl}" data-embed="${safeEmbed}" data-type="${safeType}"></div>`
}

function escapeAttr(s) {
  return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

// Enhance container: render div[data-video] plus convert anchor with video URL to embed
export function enhanceVideoContainers(root) {
  if (!root || !root.querySelectorAll) return
  // 1) Render stored placeholders - idempotent, handle React innerHTML reset (re-render) yang balikin placeholder
  const placeholders = root.querySelectorAll('div.video-embed')
  placeholders.forEach((el) => {
    // skip jika sudah ada iframe/video inner yang valid (sudah ter-render dan belum di-reset)
    if (el.querySelector('.video-embed-inner iframe, .video-embed-inner video')) return
    let raw = el.getAttribute('data-video') || el.dataset?.video || el.getAttribute('data-embed')
    if (!raw || raw === 'undefined' || raw === 'null') {
      // Fallback: cari URL dari anchor atau text di dalam placeholder jika data-video sempat terbuang
      const childLink = el.querySelector('a[href]')
      if (childLink) {
        raw = childLink.getAttribute('href')
      } else {
        const txt = el.textContent || ''
        const urlMatch = txt.match(/https?:\/\/[^\s<"]+/)
        if (urlMatch) raw = urlMatch[0]
      }
    }
    const parsed = parseVideoUrl(raw)
    if (!parsed || !parsed.embedUrl) {
      el.setAttribute('data-rendered', '1')
      return
    }
    el.setAttribute('data-video', parsed.original)
    el.setAttribute('data-embed', parsed.embedUrl)
    el.setAttribute('data-type', parsed.type)
    el.setAttribute('data-rendered', '1')
    // clear placeholder span & render responsive wrapper
    el.innerHTML = ''
    el.classList.add('video-embed--ready')
    // apply responsive outer style if not already styled via CSS class
    // create inner responsive container
    const wrapper = document.createElement('div')
    wrapper.className = 'video-embed-inner'
    if (parsed.type === 'mp4') {
      const vid = document.createElement('video')
      vid.setAttribute('controls', '')
      vid.setAttribute('preload', 'metadata')
      vid.setAttribute('playsinline', '')
      vid.style.width = '100%'
      vid.style.borderRadius = '8px'
      vid.style.background = '#000'
      vid.src = parsed.embedUrl
      wrapper.appendChild(vid)
    } else {
      const iframe = document.createElement('iframe')
      iframe.src = parsed.embedUrl
      iframe.setAttribute('frameborder', '0')
      iframe.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share')
      iframe.setAttribute('allowfullscreen', '')
      iframe.setAttribute('loading', 'lazy')
      iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin')
      iframe.setAttribute('title', 'Video player')
      wrapper.appendChild(iframe)
    }
    el.appendChild(wrapper)
  })

  // 2) Auto-convert plain links (anchor) that are video URLs and not already inside an embed
  const anchors = root.querySelectorAll('a[href]:not([data-video-link-processed])')
  anchors.forEach((a) => {
    const href = a.getAttribute('href') || ''
    const parsed = parseVideoUrl(href)
    if (!parsed) return
    // avoid double inside video-embed
    if (a.closest('.video-embed')) return
    a.setAttribute('data-video-link-processed', '1')
    // Don't replace if anchor text is clearly not just the URL (user made custom text). In that case keep link but add embed below?
    // Requirement: user paste link -> auto embed and prevent out-of-form click. So we embed.
    // Strategy: if anchor's text is same as href (paste case), replace anchor with embed div; otherwise insert embed after anchor and keep link text but prevent navigation? Keep link as fallback.
    const text = (a.textContent || '').trim()
    const isBareUrl = text === href || text === href.replace(/^https?:\/\//, '') || href.includes(text.replace(/^https?:\/\//, ''))
    // create embed element to insert
    const embedDiv = document.createElement('div')
    embedDiv.className = 'video-embed video-embed--auto'
    embedDiv.setAttribute('data-video', parsed.original)
    embedDiv.setAttribute('data-embed', parsed.embedUrl)
    embedDiv.setAttribute('data-type', parsed.type)
    embedDiv.setAttribute('data-rendered', '1')
    const inner = document.createElement('div')
    inner.className = 'video-embed-inner'
    if (parsed.type === 'mp4') {
      const vid = document.createElement('video')
      vid.setAttribute('controls', '')
      vid.setAttribute('preload', 'metadata')
      vid.setAttribute('playsinline', '')
      vid.style.width = '100%'
      vid.style.borderRadius = '8px'
      vid.style.background = '#000'
      vid.src = parsed.embedUrl
      inner.appendChild(vid)
    } else {
      const iframe = document.createElement('iframe')
      iframe.src = parsed.embedUrl
      iframe.setAttribute('frameborder', '0')
      iframe.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share')
      iframe.setAttribute('allowfullscreen', '')
      iframe.setAttribute('loading', 'lazy')
      iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin')
      iframe.setAttribute('title', 'Video player')
      inner.appendChild(iframe)
    }
    embedDiv.appendChild(inner)

    if (isBareUrl) {
      // replace the anchor's parent p? but keep block structure safe: replace anchor with embed and keep anchor as small fallback
      // replace anchor node with embed, and insert small link below for accessibility
      const fallback = document.createElement('div')
      fallback.style.fontSize = '12px'
      fallback.style.marginTop = '6px'
      fallback.style.opacity = '0.6'
      // keep fallback hidden? but allow copy
      // For exam mode we prevent navigation: remove href click handling? Keep text but not clickable to avoid keluar form? Better keep link but intercept?
      // We'll hide fallback to prevent keluar form accidentally; uncomment if need.
      // fallback.innerHTML = `<a href="#" onclick="return false" style="pointer-events:none; color:inherit;">Sumber: ${escapeAttr(href)}</a>`
      a.replaceWith(embedDiv)
      // insert fallback after embed if needed but not required
    } else {
      // insert after anchor
      a.insertAdjacentElement('afterend', embedDiv)
      // prevent default navigation on anchor to avoid keluar form - intercept click, show hint?
      a.addEventListener('click', (e) => {
        // allow ctrl+click? For exam we block
        e.preventDefault()
        // scroll to embed
        embedDiv.scrollIntoView({ behavior: 'smooth', block: 'center' })
      })
    }
  })
}

// Helper for handling paste text that contains bare URLs without anchor: scan text nodes for video URLs
export function autoLinkBareVideoUrls(html) {
  // This operates on HTML string before render: wrap bare URLs that are video links into placeholder divs
  // Only run if html contains known domains
  if (!html || typeof html !== 'string') return html
  if (!/(youtube\.com|youtu\.be|vimeo\.com|drive\.google\.com)/i.test(html)) {
    // quick check for bare mp4 maybe? but skip to avoid false positive
    if (!/\.mp4/i.test(html)) return html
  }
  // Avoid double-wrapping if already inside data-video or href
  // Simple approach: replace >https://...youtube...<  -> div placeholder if not inside <a
  // We use a placeholder technique: split by tags, only process text chunks
  const parts = html.split(/(<[^>]+>)/g)
  let changed = false
  for (let i = 0; i < parts.length; i++) {
    const p = parts[i]
    if (!p || p.startsWith('<')) continue
    // only text chunk: find video URLs
    const urlRegex = /https?:\/\/[^\s<"]+/gi
    let m
    let last = 0
    let out = ''
    let has = false
    urlRegex.lastIndex = 0
    while ((m = urlRegex.exec(p)) !== null) {
      const url = m[0]
      const parsed = parseVideoUrl(url)
      if (!parsed) continue
      has = true
      out += escapeHtml(p.slice(last, m.index))
      out += createVideoEmbedHtml(url) || url
      last = m.index + url.length
    }
    if (has) {
      if (last < p.length) out += escapeHtml(p.slice(last))
      parts[i] = out
      changed = true
    }
  }
  return changed ? parts.join('') : html
}

function escapeHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}
