// Utility video embed: YouTube, Vimeo, Google Drive, MP4 direct
// Simpan sebagai <div class="video-embed" data-video="..."> agar lolos sanitizer backend
// Frontend enhance jadi iframe/video saat render

export function parseVideoUrl(raw) {
  if (!raw || typeof raw !== 'string') return null
  let url = raw.trim()
  if (!url) return null
  // normalisasi tanpa spasi
  // YouTube patterns: https://www.youtube.com/watch?v=ID, youtu.be/ID, shorts/ID, embed/ID
  const ytRegex = /(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([a-zA-Z0-9_-]{6,11})/
  const ytMatch = url.match(ytRegex)
  if (ytMatch) {
    const id = ytMatch[1]
    return { type: 'youtube', id, embedUrl: `https://www.youtube.com/embed/${id}`, original: url }
  }
  // Vimeo: https://vimeo.com/123456789 atau player.vimeo.com/video/123
  const vimeoRegex = /(?:vimeo\.com\/(?:video\/)?)(\d{6,})/
  const vm = url.match(vimeoRegex)
  if (vm) {
    const id = vm[1]
    return { type: 'vimeo', id, embedUrl: `https://player.vimeo.com/video/${id}`, original: url }
  }
  // Google Drive: https://drive.google.com/file/d/FILEID/view atau open?id=FILEID atau drive.google.com/file/d/FILEID/preview
  const driveIdMatch = url.match(/drive\.google\.com\/(?:file\/d\/|open\?id=)([a-zA-Z0-9_-]+)/)
  if (driveIdMatch) {
    const id = driveIdMatch[1]
    // preview endpoint works for embed
    return { type: 'drive', id, embedUrl: `https://drive.google.com/file/d/${id}/preview`, original: url }
  }
  // Direct video file: .mp4 .webm .ogg .mov (case insensitive, allow querystring)
  const isDirect = /\.(mp4|webm|ogg|mov)(\?.*)?$/i.test(url)
  if (isDirect) {
    // also allow blob/data? but only https http prefix filtered elsewhere
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
  const placeholders = root.querySelectorAll('div.video-embed[data-video]')
  placeholders.forEach((el) => {
    // skip jika sudah ada iframe/video inner yang valid (sudah ter-render dan belum di-reset)
    if (el.querySelector('.video-embed-inner iframe, .video-embed-inner video')) return
    const raw = el.getAttribute('data-video') || el.dataset.video
    const parsed = parseVideoUrl(raw)
    if (!parsed) {
      el.setAttribute('data-rendered', '1')
      return
    }
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
