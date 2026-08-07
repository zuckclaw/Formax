const STORAGE_KEY_FORMS = 'formax_user_forms'
const STORAGE_KEY_TEMPLATES = 'formax_user_templates'

const defaultMockForms = [
  {
    id: 1,
    title: 'Quizz',
    slug: 'quizz',
    status: 'Published',
    responses: 12,
    updatedAt: '2 days ago',
    updatedTimestamp: Date.now() - 2 * 24 * 60 * 60 * 1000,
    category: 'Quiz',
  },
  {
    id: 2,
    title: 'Ujian',
    slug: 'ujian',
    status: 'Published',
    responses: 45,
    updatedAt: '1 week ago',
    updatedTimestamp: Date.now() - 7 * 24 * 60 * 60 * 1000,
    category: 'Exam',
  },
  {
    id: 3,
    title: 'Angket Classmeet',
    slug: 'angket-classmeet',
    status: 'Published',
    responses: 89,
    updatedAt: '1 month ago',
    updatedTimestamp: Date.now() - 30 * 24 * 60 * 60 * 1000,
    category: 'Survey',
  },
]

const defaultBuiltInTemplates = [
  {
    id: 'blank',
    title: 'Blank Form',
    subtitle: 'Start from scratch',
    type: 'blank',
  },
  {
    id: 'attendance',
    title: 'Attendance Form',
    subtitle: 'Event or class tracking',
    type: 'attendance',
  },
  {
    id: 'exam',
    title: 'Exam Form',
    subtitle: 'Assessments & Quizzes',
    badge: 'Timer enabled by default',
    type: 'exam',
  },
]

const defaultMyTemplates = [
  {
    id: 101,
    title: 'Quarterly Review',
    description: 'Template evaluasi triwulan',
    questions: 10,
    updatedAt: 'Updated 2 days ago',
  },
  {
    id: 102,
    title: 'Customer Onboardi',
    description: 'Form onboarding pelanggan baru',
    questions: 6,
    updatedAt: 'Updated 1 week ago',
  },
  {
    id: 103,
    title: 'Weekly Sync',
    description: 'Catatan pertemuan mingguan',
    questions: 4,
    updatedAt: 'Updated 1 month ago',
  },
]

const getLocalForms = () => {
  try {
    const data = localStorage.getItem(STORAGE_KEY_FORMS)
    return data ? JSON.parse(data) : defaultMockForms
  } catch (e) {
    return defaultMockForms
  }
}

const saveLocalForms = (forms) => {
  try {
    localStorage.setItem(STORAGE_KEY_FORMS, JSON.stringify(forms))
  } catch (e) {
    console.error('Failed to save forms', e)
  }
}

const getLocalTemplates = () => {
  try {
    const data = localStorage.getItem(STORAGE_KEY_TEMPLATES)
    return data ? JSON.parse(data) : defaultMyTemplates
  } catch (e) {
    return defaultMyTemplates
  }
}

const saveLocalTemplates = (templates) => {
  try {
    localStorage.setItem(STORAGE_KEY_TEMPLATES, JSON.stringify(templates))
  } catch (e) {
    console.error('Failed to save templates', e)
  }
}

const wait = () => new Promise((resolve) => setTimeout(resolve, 150))

const resolveResourceData = (payload, fallback = []) => {
  if (Array.isArray(payload)) return payload
  if (Array.isArray(payload?.data)) return payload.data
  if (Array.isArray(payload?.items)) return payload.items
  if (Array.isArray(payload?.results)) return payload.results
  if (Array.isArray(payload?.data?.items)) return payload.data.items
  if (Array.isArray(payload?.data?.results)) return payload.data.results
  if (payload && typeof payload === 'object') {
    return payload?.data ?? payload?.item ?? payload?.result ?? payload?.record ?? fallback
  }
  return fallback
}

export const getForms = async () => {
  try {
    const response = await requestWithFallbacks('get', ['/forms', '/form'], null)
    const serverData = resolveResourceData(response.data, [])
    return serverData.length > 0 ? serverData : getLocalForms()
  } catch (error) {
    await wait()
    return getLocalForms()
  }
}

export const getBuiltInTemplates = () => {
  return defaultBuiltInTemplates
}

export const getTemplates = async () => {
  try {
    const response = await requestWithFallbacks('get', ['/templates', '/template'], null)
    const serverData = resolveResourceData(response.data, [])
    return serverData.length > 0 ? serverData : getLocalTemplates()
  } catch (error) {
    await wait()
    return getLocalTemplates()
  }
}

export const createForm = async (payload) => {
  const newItem = {
    id: Date.now(),
    title: payload.title || 'Form Baru',
    slug: payload.slug || 'form-baru',
    status: payload.status || 'Published',
    responses: 0,
    updatedAt: 'Just now',
    updatedTimestamp: Date.now(),
    questions: payload.questions || [],
  }

  try {
    const response = await requestWithFallbacks('post', ['/forms', '/form'], payload)
    const created = resolveResourceData(response.data, newItem)
    const current = getLocalForms()
    saveLocalForms([created, ...current])
    return created
  } catch (error) {
    await wait()
    const current = getLocalForms()
    const updated = [newItem, ...current]
    saveLocalForms(updated)
    return newItem
  }
}

export const createTemplate = async (payload) => {
  const newItem = {
    id: Date.now(),
    title: payload.title || 'Template Baru',
    description: payload.description || 'Template deskripsi',
    questions: payload.questions?.length || 0,
    updatedAt: 'Just now',
  }

  try {
    const response = await requestWithFallbacks('post', ['/templates', '/template'], payload)
    const created = resolveResourceData(response.data, newItem)
    const current = getLocalTemplates()
    saveLocalTemplates([created, ...current])
    return created
  } catch (error) {
    await wait()
    const current = getLocalTemplates()
    const updated = [newItem, ...current]
    saveLocalTemplates(updated)
    return newItem
  }
}

export const getFormById = async (id) => {
  try {
    const response = await requestWithFallbacks('get', [`/forms/${id}`, `/form/${id}`], null)
    return resolveResourceData(response.data, getLocalForms().find((item) => String(item.id) === String(id)) || null)
  } catch (error) {
    await wait()
    return getLocalForms().find((item) => String(item.id) === String(id)) || null
  }
}

export const updateForm = async (id, payload) => {
  const current = getLocalForms()
  const updatedForms = current.map((f) => (String(f.id) === String(id) ? { ...f, ...payload, updatedAt: 'Just now', updatedTimestamp: Date.now() } : f))
  saveLocalForms(updatedForms)

  try {
    const response = await requestWithFallbacks('put', [`/forms/${id}`, `/form/${id}`], payload)
    return resolveResourceData(response.data, { ...payload, id })
  } catch (error) {
    await wait()
    return { ...payload, id }
  }
}

export const deleteForm = async (id) => {
  const current = getLocalForms()
  const filtered = current.filter((f) => String(f.id) !== String(id))
  saveLocalForms(filtered)

  try {
    const response = await requestWithFallbacks('delete', [`/forms/${id}`, `/form/${id}`], null)
    return resolveResourceData(response.data, { deleted: true, id })
  } catch (error) {
    await wait()
    return { deleted: true, id }
  }
}

export const submitFormResponse = async (formId, payload) => {
  try {
    const response = await requestWithFallbacks('post', [`/forms/${formId}/responses`, `/responses`, `/form/${formId}/responses`], payload)
    return resolveResourceData(response.data, { id: Date.now(), formId, answers: payload })
  } catch (error) {
    await wait()
    return { id: Date.now(), formId, answers: payload }
  }
}

export const getFormResponses = async (formId) => {
  try {
    const response = await requestWithFallbacks('get', [`/forms/${formId}/responses`, `/responses?form_id=${formId}`, `/form/${formId}/responses`], null)
    return resolveResourceData(response.data, [])
  } catch (error) {
    await wait()
    return []
  }
}

export const deleteTemplate = async (id) => {
  const current = getLocalTemplates()
  const filtered = current.filter((t) => String(t.id) !== String(id))
  saveLocalTemplates(filtered)

  try {
    const response = await requestWithFallbacks('delete', [`/templates/${id}`, `/template/${id}`], null)
    return resolveResourceData(response.data, { deleted: true, id })
  } catch (error) {
    await wait()
    return { deleted: true, id }
  }
}

