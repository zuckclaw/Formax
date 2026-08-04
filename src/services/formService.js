import { requestWithFallbacks } from './api'

const mockForms = [
  {
    id: 1,
    title: 'Survey Kepuasan Pelanggan',
    slug: 'survey-kepuasan-pelanggan',
    status: 'Published',
    responses: 128,
  },
  {
    id: 2,
    title: 'Form Registrasi Webinar',
    slug: 'form-registrasi-webinar',
    status: 'Draft',
    responses: 36,
  },
  {
    id: 3,
    title: 'Feedback Kegiatan Internal',
    slug: 'feedback-kegiatan-internal',
    status: 'Published',
    responses: 94,
  },
]

const mockTemplates = [
  {
    id: 1,
    title: 'Template Survei Kepuasan',
    description: 'Template standar untuk survei kepuasan pelanggan.',
    questions: 8,
  },
  {
    id: 2,
    title: 'Template Pendaftaran Event',
    description: 'Form pendaftaran acara dengan field nama dan email.',
    questions: 5,
  },
  {
    id: 3,
    title: 'Template Feedback Kegiatan',
    description: 'Template evaluasi kegiatan internal perusahaan.',
    questions: 6,
  },
]

const mockFormDetails = [
  {
    id: 1,
    title: 'Survey Kepuasan Pelanggan',
    slug: 'survey-kepuasan-pelanggan',
    status: 'Published',
    questions: [
      { id: 101, label: 'Nama lengkap', type: 'text', required: true, options: [] },
      { id: 102, label: 'Alamat email', type: 'email', required: true, options: [] },
      { id: 103, label: 'Apakah Anda puas dengan layanan kami?', type: 'radio', required: true, options: [{ id: 1, label: 'Sangat Puas' }, { id: 2, label: 'Puas' }, { id: 3, label: 'Netral' }, { id: 4, label: 'Tidak Puas' }] },
      { id: 104, label: 'Fitur apa yang paling sering Anda gunakan?', type: 'checkbox', required: false, options: [{ id: 1, label: 'Dashboard' }, { id: 2, label: 'Laporan' }, { id: 3, label: 'Integrasi' }] },
    ],
  },
  {
    id: 2,
    title: 'Form Registrasi Webinar',
    slug: 'form-registrasi-webinar',
    status: 'Draft',
    questions: [
      { id: 201, label: 'Nama', type: 'text', required: true, options: [] },
      { id: 202, label: 'Email', type: 'email', required: true, options: [] },
      { id: 203, label: 'Topik preferensi', type: 'dropdown', required: false, options: [{ id: 1, label: 'Frontend' }, { id: 2, label: 'Backend' }, { id: 3, label: 'UI/UX' }] },
    ],
  },
]

const mockResponses = {
  1: [
    { id: 1, submitted_at: '2026-08-01 10:20', answers: { 101: 'Rina', 102: 'rina@email.com', 103: 'Sangat Puas', 104: ['Dashboard', 'Laporan'] } },
    { id: 2, submitted_at: '2026-08-02 09:15', answers: { 101: 'Dimas', 102: 'dimas@email.com', 103: 'Puas', 104: ['Integrasi'] } },
  ],
  2: [
    { id: 1, submitted_at: '2026-08-03 11:00', answers: { 201: 'Irfan', 202: 'irfan@email.com', 203: 'Frontend' } },
  ],
}

const wait = () => new Promise((resolve) => setTimeout(resolve, 250))

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
    return resolveResourceData(response.data, [])
  } catch (error) {
    await wait()
    return mockForms
  }
}

export const getTemplates = async () => {
  try {
    const response = await requestWithFallbacks('get', ['/templates', '/template'], null)
    return resolveResourceData(response.data, [])
  } catch (error) {
    await wait()
    return mockTemplates
  }
}

export const createForm = async (payload) => {
  try {
    const response = await requestWithFallbacks('post', ['/forms', '/form'], payload)
    return resolveResourceData(response.data, payload)
  } catch (error) {
    await wait()
    const newItem = {
      id: Date.now(),
      title: payload.title || 'Form Baru',
      slug: payload.slug || 'form-baru',
      status: payload.status || 'Draft',
      responses: 0,
    }
    return newItem
  }
}

export const createTemplate = async (payload) => {
  try {
    const response = await requestWithFallbacks('post', ['/templates', '/template'], payload)
    return resolveResourceData(response.data, payload)
  } catch (error) {
    await wait()
    return {
      id: Date.now(),
      title: payload.title || 'Template Baru',
      description: payload.description || 'Template baru',
      questions: payload.questions || 0,
    }
  }
}

export const getFormById = async (id) => {
  try {
    const response = await requestWithFallbacks('get', [`/forms/${id}`, `/form/${id}`], null)
    return resolveResourceData(response.data, mockFormDetails.find((item) => item.id === Number(id)) || null)
  } catch (error) {
    await wait()
    return mockFormDetails.find((item) => item.id === Number(id)) || null
  }
}

export const updateForm = async (id, payload) => {
  try {
    const response = await requestWithFallbacks('put', [`/forms/${id}`, `/form/${id}`], payload)
    return resolveResourceData(response.data, { ...payload, id })
  } catch (error) {
    await wait()
    return { ...payload, id }
  }
}

export const deleteForm = async (id) => {
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
    return resolveResourceData(response.data, mockResponses[Number(formId)] || [])
  } catch (error) {
    await wait()
    return mockResponses[Number(formId)] || []
  }
}

export const deleteTemplate = async (id) => {
  try {
    const response = await requestWithFallbacks('delete', [`/templates/${id}`, `/template/${id}`], null)
    return resolveResourceData(response.data, { deleted: true, id })
  } catch (error) {
    await wait()
    return { deleted: true, id }
  }
}
