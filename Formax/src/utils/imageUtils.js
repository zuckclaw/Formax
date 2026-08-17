export const MAX_IMAGE_SIZE_MB = 2
export const MAX_IMAGE_DIMENSION = 1024

export const normalizeImageDataUrl = (dataUrl, maxDim = MAX_IMAGE_DIMENSION) => {
  return new Promise((resolve, reject) => {
    if (typeof Image === 'undefined' || typeof document === 'undefined') {
      resolve(dataUrl)
      return
    }
    const img = new Image()
    img.onload = () => {
      let { width, height } = img
      if (width > maxDim || height > maxDim) {
        const scale = Math.min(maxDim / width, maxDim / height)
        width = Math.round(width * scale)
        height = Math.round(height * scale)
      }

      const canvas = document.createElement('canvas')
      canvas.width = width
      canvas.height = height
      const ctx = canvas.getContext('2d')
      ctx.fillStyle = '#ffffff'
      ctx.fillRect(0, 0, width, height)
      ctx.drawImage(img, 0, 0, width, height)

      const isPng = dataUrl.startsWith('data:image/png')
      resolve(canvas.toDataURL(isPng ? 'image/png' : 'image/jpeg', 0.85))
    }
    img.onerror = () => reject(new Error('Gagal memproses gambar.'))
    img.src = dataUrl
  })
}

export const processImageFile = (file) => {
  return new Promise((resolve, reject) => {
    if (!file.type || !file.type.startsWith('image/')) {
      reject(new Error('File harus berupa gambar (PNG, JPG, GIF, dll).'))
      return
    }
    if (file.size > MAX_IMAGE_SIZE_MB * 1024 * 1024) {
      reject(new Error(`Ukuran gambar maksimal ${MAX_IMAGE_SIZE_MB}MB.`))
      return
    }

    const reader = new FileReader()
    reader.onload = () => {
      normalizeImageDataUrl(reader.result).then(resolve).catch(reject)
    }
    reader.onerror = () => reject(new Error('Gagal membaca file.'))
    reader.readAsDataURL(file)
  })
}
