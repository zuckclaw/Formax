import { useEffect, useState, useCallback } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router-dom';
import RichTextEditor from '../components/RichTextEditor';
import { getMe, logout } from '../api/auth';
import { createForm, getForm, updateForm, generateQR } from '../api/forms';
import { getTemplate, createTemplate } from '../api/templates';
import { uploadFile } from '../api/uploads';
import {
  createQuestionInForm,
  updateQuestion,
  deleteQuestion,
  createOption,
  updateOption,
  deleteOption,
} from '../api/questions';
import { downloadTemplateDocx, previewDocxImport, confirmDocxImport } from '../api/docx';
import { apiFetch } from '../api/config';
import '../styles/form-builder.css';
import logoForm4x from '../assets/logo_form4x.png';
import ThemeToggle from '../components/ThemeToggle';
import NgrokImage from '../components/NgrokImage';

const QUESTION_TYPES = [
  { value: 'text', label: 'Teks' },
  { value: 'single_choice', label: 'Pilihan Ganda' },
  { value: 'checkbox', label: 'Checkbox' },
  { value: 'dropdown', label: 'Dropdown' },
  { value: 'date', label: 'Tanggal' },
  { value: 'file_upload', label: 'Upload File' },
];

function generateSlug(title) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .substring(0, 60) + '-' + Date.now().toString(36);
}

export default function FormBuilderPage() {
  const navigate = useNavigate();
  const { formId } = useParams();
  const [searchParams] = useSearchParams();
  const templateId = searchParams.get('template');

  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [templateSaving, setTemplateSaving] = useState(false);
  const [bannerUploading, setBannerUploading] = useState(false);
  const [activeTab, setActiveTab] = useState('soal');
  const [activeQuestion, setActiveQuestion] = useState(null);
  const [toast, setToast] = useState(null);
  const [showQrModal, setShowQrModal] = useState(false);
  const [copiedLink, setCopiedLink] = useState(false);

  // Bulk select state
  const [bulkMode, setBulkMode] = useState(false);
  const [bulkSelected, setBulkSelected] = useState(() => new Set());
  const [showBulkConfirm, setShowBulkConfirm] = useState(false);
  const [bulkDeleting, setBulkDeleting] = useState(false);
  const [confirmSingleIdx, setConfirmSingleIdx] = useState(null);

  // Import DOCX state
  const [showImportModal, setShowImportModal] = useState(false);
  const [importPhase, setImportPhase] = useState('upload'); // 'upload' | 'preview' | 'importing'
  const [importFile, setImportFile] = useState(null);
  const [importPreview, setImportPreview] = useState(null);
  const [importSelected, setImportSelected] = useState(new Set());
  const [importLoading, setImportLoading] = useState(false);
  const [importDragging, setImportDragging] = useState(false);
  const [importError, setImportError] = useState(null);


  // Form data
  const [formData, setFormData] = useState({
    id: null,
    title: '',
    description: '',
    status: 'draft',
    slug: '',
    accept_responses: true,
    allow_see_result: false,
    max_submissions: 0,
    require_fullscreen: false,
    reveal_answers: false,
    banner_url: null,
    start_date: '',
    end_date: '',
    join_token: null,
    qr_code_url: null,
  });

  // Questions (local state)
  const [questions, setQuestions] = useState([]);

  // Settings flags
  const [useJoinToken, setUseJoinToken] = useState(false);
  // Batas pengisian: 'once' | 'unlimited' | 'custom'
  const [maxSubmissionsMode, setMaxSubmissionsMode] = useState('unlimited');
  const [customMaxSubmissions, setCustomMaxSubmissions] = useState(2);

  const token = localStorage.getItem('token');

  const showToast = useCallback((msg, type = 'info') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  }, []);

  // Load initial data
  useEffect(() => {
    if (!token) {
      navigate('/auth');
      return;
    }

    const load = async () => {
      try {
        const userData = await getMe(token);
        setUser(userData);

        if (formId) {
          // Edit mode: load existing form
          const form = await getForm(token, formId);
          setFormData({
            id: form.id,
            title: form.title,
            description: form.description || '',
            status: form.status,
            slug: form.slug,
            accept_responses: form.accept_responses,
            allow_see_result: form.allow_see_result ?? false,
            max_submissions: form.max_submissions ?? 0,
            require_fullscreen: form.require_fullscreen ?? false,
            reveal_answers: form.reveal_answers ?? false,
            banner_url: form.banner_url || null,
            start_date: form.start_date ? form.start_date.substring(0, 16) : '',
            end_date: form.end_date ? form.end_date.substring(0, 16) : '',
            join_token: form.join_token,
            qr_code_url: form.qr_code_url,
          });
          const maxSub = form.max_submissions ?? 0;
          if (maxSub === 1) {
            setMaxSubmissionsMode('once');
          } else if (maxSub === 0) {
            setMaxSubmissionsMode('unlimited');
          } else {
            setMaxSubmissionsMode('custom');
            setCustomMaxSubmissions(maxSub);
          }
          setUseJoinToken(!!form.join_token);
          setQuestions(
            (form.questions || [])
              .sort((a, b) => a.order_index - b.order_index)
              .map((q) => ({
                ...q,
                _saved: true,
                options: (q.options || []).sort((a, b) => a.order_index - b.order_index).map((o) => ({ ...o, _saved: true })),
              }))
          );
        } else if (templateId) {
          // Create from template: load template questions as initial data
          try {
            const tpl = await getTemplate(token, templateId);
            setFormData((prev) => ({
              ...prev,
              title: tpl.title || '',
              description: tpl.description || '',
              banner_url: tpl.banner_url || null,
            }));
            setQuestions(
              (tpl.questions || [])
                .sort((a, b) => a.order_index - b.order_index)
                .map((q, idx) => ({
                  _tempId: `temp-${idx}`,
                  type: q.type,
                  label: q.label,
                  placeholder: q.placeholder || '',
                  is_required: q.is_required,
                  order_index: idx,
                  settings: q.settings || {},
                  options: (q.options || []).map((o, oidx) => ({
                    _tempId: `temp-opt-${idx}-${oidx}`,
                    label: o.label,
                    value: o.value || '',
                    order_index: oidx,
                    is_correct: o.is_correct || false,
                  })),
                }))
            );
          } catch {
            showToast('Gagal memuat template', 'error');
          }
        }
      } catch {
        logout();
        navigate('/auth');
      } finally {
        setLoading(false);
      }
    };

    load();
  }, [formId, templateId, token, navigate, showToast]);

  // Drawer swipe open dari edge kiri
  useEffect(() => {
    let startX = 0;
    const onTouchStart = (e) => { startX = e.touches[0].clientX; };
    const onTouchEnd = (e) => {
      const dx = e.changedTouches[0].clientX - startX;
      if (!drawerOpen && startX < 30 && dx > 80) setDrawerOpen(true);
      if (drawerOpen && dx < -80) setDrawerOpen(false);
    };
    window.addEventListener('touchstart', onTouchStart);
    window.addEventListener('touchend', onTouchEnd);
    return () => { window.removeEventListener('touchstart', onTouchStart); window.removeEventListener('touchend', onTouchEnd); };
  }, [drawerOpen]);

  // ============================================================
  // SAVE / CREATE FORM
  // ============================================================
  const handleSave = async (publish = false) => {
    if (!formData.title.trim()) {
      showToast('Judul form tidak boleh kosong', 'error');
      return;
    }

    const statusToSave = publish ? 'published' : formData.status;

    setSaving(true);
    try {
      if (formData.id) {
        // Rekomendasi: atomic save — kirim semua questions sekali via PATCH /forms/{id}
        // Ini fix bug "hapus soal lalu Simpan Draf malah nambah": sebelumnya loop per-question
        // hanya update/create (q.id && _saved) tanpa delete orphan, dan skip q.id && !_saved.
        // Backend forms.py:211 akan delete orphan atomik. Jika sudah ada submission, backend 409 (sengaja).
        const questionsPayload = questions.map((q, idx) => ({
          type: q.type,
          label: q.label,
          placeholder: q.placeholder || '',
          is_required: q.is_required,
          order_index: idx,
          settings: q.settings || {},
          options: (q.options || []).map((o, oidx) => ({
            label: o.label,
            value: o.value || '',
            order_index: oidx,
            is_correct: !!o.is_correct,
            is_other: !!o.is_other,
          })),
        }));

        let updatedForm;
        try {
          updatedForm = await updateForm(token, formData.id, {
            title: formData.title,
            description: formData.description,
            status: statusToSave,
            accept_responses: formData.accept_responses,
            allow_see_result: formData.allow_see_result,
            max_submissions: formData.max_submissions,
            require_fullscreen: formData.require_fullscreen,
            reveal_answers: formData.reveal_answers,
            banner_url: formData.banner_url,
            start_date: formData.start_date || null,
            end_date: formData.end_date || null,
            questions: questionsPayload,
          });
        } catch (err) {
          // Rekomendasi 2: jika form sudah ada jawaban, backend 409 — jangan hilangkan data
          if (err.message && err.message.toLowerCase().includes('sudah punya jawaban')) {
            showToast('Form sudah ada jawaban responden — hapus soal akan menghapus jawaban. Duplikasi form dulu jika perlu.', 'error');
            throw err;
          }
          throw err;
        }

        // Sync local state dari response atomik (sudah pasti _saved)
        if (updatedForm && updatedForm.questions) {
          setQuestions(
            updatedForm.questions
              .sort((a, b) => a.order_index - b.order_index)
              .map((q) => ({
                ...q,
                _saved: true,
                options: (q.options || []).sort((a, b) => a.order_index - b.order_index).map((o) => ({ ...o, _saved: true })),
              }))
          );
        }

        if (publish) {
          setFormData((prev) => ({ ...prev, status: 'published', title: updatedForm?.title ?? prev.title, description: updatedForm?.description ?? prev.description }));
          showToast('Form berhasil dipublikasikan! Link siap dibagikan.', 'success');
          if (formData.id) {
            try {
              const qr = await generateQR(token, formData.id);
              setFormData((prev) => ({ ...prev, qr_code_url: qr.qr_code_url }));
            } catch { /* ignore */ }
          }
        } else {
          showToast('Form berhasil disimpan!', 'success');
        }
      } else {
        // Create new form
        const slug = formData.slug || generateSlug(formData.title);
        const payload = {
          title: formData.title,
          description: formData.description,
          status: statusToSave,
          accept_responses: formData.accept_responses,
          allow_see_result: formData.allow_see_result,
          max_submissions: formData.max_submissions,
          require_fullscreen: formData.require_fullscreen,
          reveal_answers: formData.reveal_answers,
          slug,
          template_id: templateId || null,
          banner_url: formData.banner_url,
          start_date: formData.start_date || null,
          end_date: formData.end_date || null,
          use_join_token: useJoinToken,
          questions: templateId
            ? []
            : questions.map((q, idx) => ({
                type: q.type,
                label: q.label,
                placeholder: q.placeholder || '',
                is_required: q.is_required,
                order_index: idx,
                settings: q.settings || {},
                options: (q.options || []).map((o, oidx) => ({
                  label: o.label,
                  value: o.value || '',
                  order_index: oidx,
                  is_correct: o.is_correct || false,
                })),
              })),
        };

        const created = await createForm(token, payload);
        setFormData((prev) => ({
          ...prev,
          id: created.id,
          slug: created.slug,
          join_token: created.join_token,
          banner_url: created.banner_url || prev.banner_url,
        }));

        let savedQuestions = (created.questions || []).sort((a, b) => a.order_index - b.order_index);

        // Fallback: If backend returned no questions but local questions existed, save them explicitly
        if (savedQuestions.length === 0 && questions.length > 0) {
          const newSaved = [];
          for (let i = 0; i < questions.length; i++) {
            const q = questions[i];
            const newQ = await createQuestionInForm(token, created.id, {
              type: q.type,
              label: q.label || 'Pertanyaan Tanpa Judul',
              placeholder: q.placeholder || '',
              is_required: q.is_required,
              order_index: i,
              settings: q.settings || {},
              options: (q.options || []).map((o, oidx) => ({
                label: o.label || `Opsi ${oidx + 1}`,
                value: o.value || '',
                order_index: oidx,
                is_correct: o.is_correct || false,
              })),
            });
            newSaved.push(newQ);
          }
          savedQuestions = newSaved;
        }

        setQuestions(
          savedQuestions.map((q) => ({
            ...q,
            _saved: true,
            options: (q.options || []).map((o) => ({ ...o, _saved: true })),
          }))
        );

        // Update URL to edit mode without reloading
        window.history.replaceState(null, '', `/form-builder/${created.id}`);
        if (publish) {
          setFormData((prev) => ({ ...prev, status: 'published' }));
          showToast('Form berhasil dipublikasikan! Link siap dibagikan.', 'success');
        } else {
          showToast('Form berhasil disimpan!', 'success');
        }
        if (publish && created.id) {
          try {
            const qr = await generateQR(token, created.id);
            setFormData((prev) => ({ ...prev, qr_code_url: qr.qr_code_url }));
          } catch { /* ignore */ }
        }
      }
    } catch (err) {
      showToast(err.message || 'Gagal menyimpan form', 'error');
    } finally {
      setSaving(false);
    }
  };

  // ============================================================
  // SAVE AS NEW TEMPLATE (dengan konfirmasi)
  // ============================================================
  const [showConfirmTemplateSave, setShowConfirmTemplateSave] = useState(false);

  const handleSaveAsTemplate = async () => {
    if (!formData.title.trim()) {
      showToast('Judul template tidak boleh kosong', 'error');
      return;
    }
    // FIX: tampilkan dialog konfirmasi dulu, bukan langsung save saat refresh/load
    setShowConfirmTemplateSave(true);
  };

  const confirmSaveAsTemplate = async () => {
    setShowConfirmTemplateSave(false);
    setTemplateSaving(true);
    try {
      const created = await createTemplate(token, {
        title: formData.title,
        description: formData.description,
        banner_url: formData.banner_url,
        questions: questions.map((q, idx) => ({
          type: q.type,
          label: q.label,
          placeholder: q.placeholder || '',
          is_required: q.is_required,
          order_index: idx,
          settings: q.settings || {},
          options: (q.options || []).map((o, oidx) => ({
            label: o.label,
            value: o.value || '',
            order_index: oidx,
            is_correct: o.is_correct || false,
          })),
        })),
      });
      showToast('Template berhasil disimpan! Muncul di Dashboard > Template', 'success');
    } catch (err) {
      showToast(err.message || 'Gagal menyimpan template', 'error');
    } finally {
      setTemplateSaving(false);
    }
  };

  // ============================================================
  // QUESTION MANAGEMENT (local state)
  // ============================================================
  const addQuestion = () => {
    const newQ = {
      _tempId: `temp-${Date.now()}`,
      type: 'single_choice',
      label: '',
      placeholder: '',
      is_required: allRequired,
      order_index: questions.length,
      settings: {},
      options: [
        { _tempId: `temp-opt-${Date.now()}-0`, label: 'Opsi 1', value: '', order_index: 0, is_correct: false },
      ],
    };
    setQuestions((prev) => [...prev, newQ]);
    setActiveQuestion(newQ._tempId || newQ.id);
  };

  const duplicateQuestion = (index) => {
    const original = questions[index];
    const copy = {
      ...original,
      id: undefined,
      _tempId: `temp-${Date.now()}`,
      _saved: false,
      order_index: questions.length,
      options: (original.options || []).map((o, oidx) => ({
        ...o,
        id: undefined,
        _tempId: `temp-opt-dup-${Date.now()}-${oidx}`,
        _saved: false,
      })),
    };
    setQuestions((prev) => [...prev.slice(0, index + 1), copy, ...prev.slice(index + 1)]);
  };

  const removeQuestion = async (index) => {
    const q = questions[index];
    if (q.id) {
      try {
        await deleteQuestion(token, q.id);
      } catch (err) {
        showToast(err.message, 'error');
        return;
      }
    }
    setQuestions((prev) => prev.filter((_, i) => i !== index));
  };

  // Bulk helpers
  const getQKey = (q) => q.id || q._tempId;
  const isAllSelected = questions.length > 0 && bulkSelected.size === questions.length;
  const toggleBulkSelect = (key) => {
    setBulkSelected((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };
  const toggleBulkSelectAll = () => {
    if (isAllSelected) setBulkSelected(new Set());
    else setBulkSelected(new Set(questions.map(getQKey)));
  };
  const handleBulkDelete = () => {
    if (bulkSelected.size === 0) return;
    setShowBulkConfirm(true);
  };
  const executeBulkDelete = async () => {
    if (bulkSelected.size === 0) return;
    setBulkDeleting(true);
    const toDelete = questions.filter((q) => bulkSelected.has(getQKey(q)) && q.id);
    for (const q of toDelete) {
      try {
        await deleteQuestion(token, q.id);
      } catch (err) {
        showToast(err.message || 'Gagal menghapus beberapa soal', 'error');
        setBulkDeleting(false);
        return;
      }
    }
    const count = bulkSelected.size;
    setQuestions((prev) => prev.filter((q) => !bulkSelected.has(getQKey(q))).map((q, idx) => ({ ...q, order_index: idx })));
    setBulkSelected(new Set());
    setBulkMode(false);
    setActiveQuestion(null);
    setShowBulkConfirm(false);
    setBulkDeleting(false);
    showToast(`${count} pertanyaan berhasil dihapus`, 'success');
  };
  const executeSingleDelete = async () => {
    if (confirmSingleIdx === null) return;
    const q = questions[confirmSingleIdx];
    if (!q) return;
    if (q.id) {
      try {
        await deleteQuestion(token, q.id);
      } catch (err) {
        showToast(err.message, 'error');
        return;
      }
    }
    setQuestions((prev) => prev.filter((_, i) => i !== confirmSingleIdx).map((qq, idx) => ({ ...qq, order_index: idx })));
    if (activeQuestion === getQKey(q)) setActiveQuestion(null);
    setConfirmSingleIdx(null);
    showToast('Pertanyaan dihapus', 'success');
  };

  const updateQuestionLocal = (index, updates) => {
    setQuestions((prev) => prev.map((q, i) => (i === index ? { ...q, ...updates, _saved: false } : q)));
  };

  // Option management
  const addOptionToQuestion = (qIndex) => {
    setQuestions((prev) =>
      prev.map((q, i) =>
        i === qIndex
          ? {
              ...q,
              _saved: false,
              options: [
                ...q.options,
                {
                  _tempId: `temp-opt-${Date.now()}`,
                  label: `Opsi ${q.options.length + 1}`,
                  value: '',
                  order_index: q.options.length,
                  is_correct: false,
                },
              ],
            }
          : q
      )
    );
  };

  const updateOptionLocal = (qIndex, oIndex, updates) => {
    setQuestions((prev) =>
      prev.map((q, i) =>
        i === qIndex
          ? {
              ...q,
              _saved: false,
              options: q.options.map((o, j) => (j === oIndex ? { ...o, ...updates, _saved: false } : o)),
            }
          : q
      )
    );
  };

  const removeOptionLocal = async (qIndex, oIndex) => {
    const opt = questions[qIndex].options[oIndex];
    if (opt.id) {
      try {
        await deleteOption(token, opt.id);
      } catch (err) {
        showToast(err.message, 'error');
        return;
      }
    }
    setQuestions((prev) =>
      prev.map((q, i) =>
        i === qIndex ? { ...q, _saved: false, options: q.options.filter((_, j) => j !== oIndex) } : q
      )
    );
  };

  // Tandai SATU opsi sebagai jawaban benar (kunci jawaban). Klik lagi = hapus kunci.
  const markCorrectOption = (qIndex, oIndex) => {
    setQuestions((prev) =>
      prev.map((q, i) =>
        i === qIndex
          ? {
              ...q,
              _saved: false,
              options: q.options.map((o, j) => ({
                ...o,
                is_correct: j === oIndex ? !o.is_correct : false,
                _saved: false,
              })),
            }
          : q
      )
    );
  };

  const getPublicLink = () => {
    return `${window.location.origin}/f/${formData.slug}`;
  };

  const handleCopyLink = () => {
    const link = getPublicLink();
    navigator.clipboard.writeText(link);
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2000);
  };

  const handleGenerateQR = async () => {
    if (!formData.id) {
      showToast('Simpan form terlebih dahulu', 'error');
      return;
    }
    try {
      const result = await generateQR(token, formData.id);
      setFormData((prev) => ({ ...prev, qr_code_url: result.qr_code_url }));
      setShowQrModal(true);
      showToast('QR Code berhasil dibuat!', 'success');
    } catch (err) {
      showToast(err.message, 'error');
    }
  };

  // ============================================================
  // IMPORT DOCX HANDLERS
  // ============================================================
  const resetImportModal = () => {
    setShowImportModal(false);
    setImportPhase('upload');
    setImportFile(null);
    setImportPreview(null);
    setImportSelected(new Set());
    setImportLoading(false);
    setImportDragging(false);
    setImportError(null);
  };

  const handleDownloadTemplate = async () => {
    try {
      await downloadTemplateDocx(token);
      showToast('Template berhasil diunduh!', 'success');
    } catch (err) {
      showToast(err.message, 'error');
    }
  };

  const handleFileSelect = async (file) => {
    if (!file) return;
    if (!file.name.toLowerCase().endsWith('.docx')) {
      setImportError('File harus berformat .docx (Word modern), bukan .doc lama');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      setImportError('Ukuran file maksimal 5 MB');
      return;
    }

    setImportFile(file);
    setImportLoading(true);
    setImportError(null);

    try {
      const result = await previewDocxImport(token, formData.id, file);
      setImportPreview(result);

      const validIds = new Set();
      result.questions.forEach((q) => {
        if (q.errors.length === 0) validIds.add(q.number);
      });
      setImportSelected(validIds);
      setImportPhase('preview');
    } catch (err) {
      setImportError(err.message);
      setImportFile(null);
    } finally {
      setImportLoading(false);
    }
  };

  const handleImportConfirm = async () => {
    if (!importPreview || importSelected.size === 0) return;

    setImportPhase('importing');
    setImportLoading(true);

    try {
      const selectedQuestions = importPreview.questions
        .filter((q) => importSelected.has(q.number))
        .map((q) => ({
          label: q.label,
          is_required: false,
          options: q.options.map((o) => ({
            label: o.label,
            value: o.value || o.label,
            order_index: o.order_index,
            is_correct: o.is_correct,
          })),
        }));

      const result = await confirmDocxImport(token, formData.id, selectedQuestions);
      showToast(result.message || `${selectedQuestions.length} soal berhasil diimpor!`, 'success');

      // Reload form to get fresh questions
      try {
        const freshForm = await getForm(token, formData.id);
        setQuestions(
          (freshForm.questions || [])
            .sort((a, b) => a.order_index - b.order_index)
            .map((q) => ({
              ...q,
              _saved: true,
              options: (q.options || []).sort((a, b) => a.order_index - b.order_index).map((o) => ({ ...o, _saved: true })),
            }))
        );
      } catch {
        // If reload fails, just close modal
      }

      resetImportModal();
    } catch (err) {
      showToast(err.message, 'error');
      setImportPhase('preview');
    } finally {
      setImportLoading(false);
    }
  };

  const handleImportDrop = (e) => {
    e.preventDefault();
    setImportDragging(false);
    const file = e.dataTransfer.files?.[0];
    if (file) handleFileSelect(file);
  };

  const handleImportDragOver = (e) => {
    e.preventDefault();
    setImportDragging(true);
  };

  const handleImportDragLeave = (e) => {
    e.preventDefault();
    setImportDragging(false);
  };

  const toggleImportQuestion = (number) => {
    const q = importPreview?.questions?.find((q) => q.number === number);
    if (q && q.errors.length > 0) return; // can't select error questions

    setImportSelected((prev) => {
      const next = new Set(prev);
      if (next.has(number)) {
        next.delete(number);
      } else {
        next.add(number);
      }
      return next;
    });
  };

  const toggleImportSelectAll = () => {
    if (!importPreview) return;
    const validNumbers = importPreview.questions
      .filter((q) => q.errors.length === 0)
      .map((q) => q.number);

    if (importSelected.size === validNumbers.length) {
      setImportSelected(new Set());
    } else {
      setImportSelected(new Set(validNumbers));
    }
  };


  // ============================================================
  // BANNER
  // ============================================================
  const handleBannerUpload = async (e) => {
    const file = e.target.files && e.target.files[0];
    if (!file) return;
    setBannerUploading(true);
    try {
      const result = await uploadFile(token, file);
      const cleanUrl = (result.file_url || '').trim();
      console.log('[Banner] uploaded URL:', cleanUrl);
      setFormData((prev) => ({ ...prev, banner_url: cleanUrl }));
      showToast('Banner berhasil diupload — jangan lupa klik Simpan Draf', 'success');
    } catch (err) {
      console.error('[Banner] upload failed:', err);
      showToast(err.message, 'error');
    } finally {
      setBannerUploading(false);
      e.target.value = '';
    }
  };

  const handleRemoveBanner = () => {
    setFormData((prev) => ({ ...prev, banner_url: null }));
  };

  // ============================================================
  // HELPERS
  // ============================================================
  const getInitials = (name = '') =>
    name.split(' ').slice(0, 2).map((w) => w[0]).join('').toUpperCase();

  const hasOptions = (type) => ['single_choice', 'checkbox', 'dropdown'].includes(type);

  const supportsCorrectAnswer = (type) => ['single_choice', 'dropdown'].includes(type);

  const getOptionIndicator = (type) => {
    if (type === 'single_choice') return 'fb-option-radio';
    if (type === 'checkbox') return 'fb-option-checkbox';
    return null;
  };

  // Global wajib isi — bulk set semua pertanyaan (A)
  const allRequired = questions.length > 0 && questions.every((q) => q.is_required);
  const setAllRequired = (val) => {
    if (questions.length === 0) {
      showToast('Tambah soal dulu', 'error');
      return;
    }
    setQuestions((prev) => prev.map((q) => ({ ...q, is_required: val, _saved: false })));
    showToast(
      val ? `Semua ${questions.length} soal dijadikan wajib diisi` : 'Semua soal dijadikan tidak wajib',
      'success'
    );
  };

  if (loading) {
    return (
      <div className="fb-loading">
        <div className="db-spinner" />
        <p>Memuat form builder...</p>
      </div>
    );
  }

  return (
    <div className="db-root">
      {/* Sidebar (shared with dashboard) */}
      {drawerOpen && <div className="db-drawer-backdrop" onClick={() => setDrawerOpen(false)} aria-hidden="true" />}
      <aside className={`db-sidebar ${drawerOpen ? 'open' : ''}`}>
        <div className="db-logo">
          <div className="db-logo-icon">
            <img src={logoForm4x} alt="Form4x logo" className="db-logo-img" />
          </div>
          <div className="db-logo-text">
            <span className="db-logo-name">Form4x</span>
            <span className="db-logo-tagline">Tempat membuat Form Terlengkap</span>
          </div>
        </div>

        <nav className="db-nav">
          <button className="db-nav-item" onClick={() => { setDrawerOpen(false); navigate('/dashboard'); }}>
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" />
              <rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" />
            </svg>
            <span>Dasbor</span>
          </button>
          <button className="db-nav-item" onClick={() => { setDrawerOpen(false); navigate('/dashboard'); }}>
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <rect x="3" y="3" width="18" height="18" rx="2" /><path d="M3 9h18M9 21V9" />
            </svg>
            <span>Templat</span>
          </button>
          <button className="db-nav-item" onClick={() => { setDrawerOpen(false); navigate('/dashboard'); }}>
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <polyline points="1 4 1 10 7 10" /><path d="M3.51 15a9 9 0 1 0 .49-4.39" />
            </svg>
            <span>Riwayat</span>
          </button>
        </nav>

        <div className="db-sidebar-footer">
          <div className="db-user">
            <div className="db-avatar">
              {user?.avatar_url ? <img src={user.avatar_url} alt={user.full_name} /> : <span>{getInitials(user?.full_name)}</span>}
            </div>
            <div className="db-user-info">
              <span className="db-user-name">{user?.full_name}</span>
              <span className="db-user-email">{user?.email}</span>
            </div>
          </div>
          <button className="db-logout-btn" onClick={() => { logout(); navigate('/auth'); }} aria-label="Logout">
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" /><polyline points="16 17 21 12 16 7" /><line x1="21" y1="12" x2="9" y2="12" />
            </svg>
          </button>
        </div>
      </aside>

        {/* Main */}
      <main className="fb-main">
        {/* Topbar */}
        <header className="fb-topbar">
          <div className="fb-topbar-left">
            <button className="fb-hamburger" onClick={() => setDrawerOpen((v) => !v)} aria-label="Toggle menu">
              <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><line x1="3" y1="6" x2="21" y2="6" /><line x1="3" y1="12" x2="21" y2="12" /><line x1="3" y1="18" x2="21" y2="18" /></svg>
            </button>
            <button className="fb-back-btn" onClick={() => navigate('/dashboard', { state: { reloadTemplates: true } })} aria-label="Back to dashboard">
              <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <polyline points="15 18 9 12 15 6" />
              </svg>
            </button>
          </div>

          <div className="fb-topbar-center">
            <button className={`fb-tab ${activeTab === 'soal' ? 'active' : ''}`} onClick={() => setActiveTab('soal')}>
              Soal
            </button>
            <button className={`fb-tab ${activeTab === 'setelan' ? 'active' : ''}`} onClick={() => setActiveTab('setelan')}>
              Setelan
            </button>
          </div>

          <div className="fb-topbar-actions">
            <ThemeToggle />
            <button
              className="fb-import-btn"
              onClick={() => {
                if (!formData.id) {
                  showToast('Simpan form terlebih dahulu, lalu klik Import Word', 'error');
                  return;
                }
                setShowImportModal(true);
              }}
              title="Import soal dari file Word (.docx)"
            >
              <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
                <polyline points="14 2 14 8 20 8" />
                <line x1="12" y1="18" x2="12" y2="12" />
                <polyline points="9 15 12 18 15 15" />
              </svg>
              Import Word
            </button>
            <button className="fb-template-btn" onClick={handleSaveAsTemplate} disabled={templateSaving} title="Simpan soal-soal ini sebagai template baru">
              <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><rect x="3" y="3" width="18" height="18" rx="2" /><path d="M9 12h6M12 9v6" /></svg>
              {templateSaving ? 'Menyimpan...' : 'Template'}
            </button>
            <button className="fb-save-btn" onClick={() => handleSave(false)} disabled={saving}>
              <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" /><polyline points="17 21 17 13 7 13 7 21" /><polyline points="9 9 9 3 15 3 15 9" /></svg>
              {saving ? '...' : 'Simpan'}
            </button>
            <button
              className={`fb-publish-btn ${formData.status === 'published' ? 'is-published' : ''}`}
              onClick={() => handleSave(true)}
              disabled={saving}
              title={formData.status === 'published' ? 'Perbarui publikasi' : 'Publikasikan agar link bisa diisi responden (Status → Published)'}
            >
              <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path d="M22 11.08V12a10 10 0 11-5.93-9.14" />
                <polyline points="22 4 12 14.01 9 11.01" />
              </svg>
              {formData.status === 'published' ? 'Perbarui' : 'Publish'}
            </button>
          </div>
        </header>

        {/* Mobile bottom bar — 1 baris kecil rapih */}
        <div className="fb-mobile-bottom-bar" aria-label="Aksi form">
          <button className="fb-import-btn" onClick={() => { if (!formData.id) { showToast('Simpan form terlebih dahulu', 'error'); return; } setShowImportModal(true); }}>
            <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" /><polyline points="14 2 14 8 20 8" /><line x1="12" y1="18" x2="12" y2="12" /><polyline points="9 15 12 18 15 15" /></svg>
            Import
          </button>
          <button className="fb-template-btn" onClick={handleSaveAsTemplate} disabled={templateSaving}>
            <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><rect x="3" y="3" width="18" height="18" rx="2" /><path d="M9 12h6M12 9v6" /></svg>
            Template
          </button>
          <button className="fb-save-btn" onClick={() => handleSave(false)} disabled={saving}>
            <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" /><polyline points="17 21 17 13 7 13 7 21" /></svg>
            Simpan
          </button>
          <button className={`fb-publish-btn ${formData.status === 'published' ? 'is-published' : ''}`} onClick={() => handleSave(true)} disabled={saving}>
            <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path d="M22 11.08V12a10 10 0 11-5.93-9.14" /><polyline points="22 4 12 14.01 9 11.01" /></svg>
            {formData.status === 'published' ? 'Perbarui' : 'Publish'}
          </button>
        </div>

        {/* Content */}
        <section className="fb-content">
          {activeTab === 'soal' && (
            <>
              <div className="fb-editor-area">
                {/* Progress Bar */}
                <div className="fb-progress-bar">
                  <div
                    className="fb-progress-fill"
                    style={{
                      width: `${questions.length > 0 ? Math.min(100, (questions.filter((q) => q.label.trim()).length / questions.length) * 100) : 0}%`,
                    }}
                  />
                </div>

                {/* Form Header */}
                <div className="fb-header-card">
                  {/* Banner */}
                  {formData.banner_url ? (
                    <div className="fb-banner-wrap">
                      <NgrokImage
                        src={formData.banner_url}
                        alt="Banner form"
                        className="fb-banner-img"
                        onError={() => showToast('Gambar banner gagal dimuat — coba Simpan lalu refresh', 'error')}
                      />
                      <div className="fb-banner-actions">
                        <label className="fb-banner-btn">
                          {bannerUploading ? 'Mengupload...' : 'Ganti Banner'}
                          <input type="file" accept="image/*" hidden onChange={handleBannerUpload} disabled={bannerUploading} />
                        </label>
                        <button className="fb-banner-btn danger" onClick={handleRemoveBanner} disabled={bannerUploading}>
                          Hapus Banner
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="fb-banner-upload" onClick={() => document.getElementById('fb-banner-input')?.click()}>
                      {bannerUploading ? (
                        <span>Mengupload banner...</span>
                      ) : (
                        <>
                          <svg width="28" height="28" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                            <rect x="3" y="3" width="18" height="18" rx="2" />
                            <circle cx="8.5" cy="8.5" r="1.5" />
                            <polyline points="21 15 16 10 5 21" />
                          </svg>
                          <span>Tambahkan Banner</span>
                        </>
                      )}
                      <input
                        id="fb-banner-input"
                        type="file"
                        accept="image/*"
                        hidden
                        onChange={handleBannerUpload}
                        disabled={bannerUploading}
                      />
                    </div>
                  )}

                  <input
                    className="fb-title-input"
                    type="text"
                    placeholder="Judul Formulir"
                    value={formData.title}
                    onChange={(e) => setFormData((prev) => ({ ...prev, title: e.target.value }))}
                  />
                  <p className="fb-desc-label">Deskripsi</p>
                  <div className="fb-wysiwyg-wrap">
                    <RichTextEditor
                      value={formData.description}
                      onChange={(val) => setFormData((prev) => ({ ...prev, description: val }))}
                      variant="full"
                      placeholder="Deskripsi formulir..."
                    />
                  </div>
                </div>

                {/* Bulk action bar */}
                {questions.length > 0 && (
                  <div className={`fb-bulk-bar ${bulkMode ? 'active' : ''}`}>
                    {!bulkMode ? (
                      <>
                        <span className="fb-bulk-count">{questions.length} Soal</span>
                        <button className="fb-bulk-trigger" onClick={() => setBulkMode(true)}>
                          <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <rect x="3" y="3" width="18" height="18" rx="2" />
                            <path d="M9 12l2 2 4-4" />
                          </svg>
                          Pilih
                        </button>
                      </>
                    ) : (
                      <>
                        <label className="fb-bulk-selectall">
                          <input
                            type="checkbox"
                            className="fb-bulk-checkbox-input"
                            checked={isAllSelected}
                            onChange={toggleBulkSelectAll}
                          />
                          <span className="fb-bulk-checkmark" />
                          {isAllSelected ? 'Batalkan semua' : 'Pilih semua'}
                        </label>
                        <span className="fb-bulk-selected-count">
                          {bulkSelected.size > 0 ? `${bulkSelected.size} dipilih` : 'Belum ada yang dipilih'}
                        </span>
                        <div className="fb-bulk-actions">
                          <button
                            className="fb-bulk-delete-btn"
                            onClick={handleBulkDelete}
                            disabled={bulkSelected.size === 0}
                            title={bulkSelected.size === 0 ? 'Pilih soal terlebih dahulu' : `Hapus ${bulkSelected.size} soal`}
                          >
                            <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                              <polyline points="3 6 5 6 21 6" />
                              <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                            </svg>
                            Hapus ({bulkSelected.size})
                          </button>
                          <button
                            className="fb-bulk-cancel-btn"
                            onClick={() => { setBulkMode(false); setBulkSelected(new Set()); }}
                          >
                            Batal
                          </button>
                        </div>
                      </>
                    )}
                  </div>
                )}

                {/* Questions */}
                {questions.map((q, qIdx) => {
                  const qKey = q.id || q._tempId;
                  const isActive = activeQuestion === qKey;
                  const isBulkSelected = bulkSelected.has(qKey);

                  return (
                    <div
                      key={qKey}
                      className={`fb-question-card ${isActive ? 'active' : ''} ${isBulkSelected ? 'bulk-selected' : ''}`}
                      onClick={() => setActiveQuestion(qKey)}
                    >
                      {/* Top: type selector */}
                      <div className="fb-question-top">
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                          {bulkMode && (
                            <label className="fb-bulk-card-check" onClick={(e) => e.stopPropagation()}>
                              <input
                                type="checkbox"
                                checked={isBulkSelected}
                                onChange={() => toggleBulkSelect(qKey)}
                              />
                              <span className="fb-bulk-card-checkmark" />
                            </label>
                          )}
                          <div className="fb-question-top-label">Pertanyaan {qIdx + 1}</div>
                        </div>
                        <select
                          className="fb-type-select"
                          value={q.type}
                          onChange={(e) => {
                            const newType = e.target.value;
                            const updates = { type: newType };
                            // Add default option if switching to choice type and has no options
                            if (hasOptions(newType) && (!q.options || q.options.length === 0)) {
                              updates.options = [{ _tempId: `temp-opt-${Date.now()}`, label: 'Opsi 1', value: '', order_index: 0, is_correct: false }];
                            }
                            updateQuestionLocal(qIdx, updates);
                          }}
                        >
                          {QUESTION_TYPES.map((t) => (
                            <option key={t.value} value={t.value}>{t.label}</option>
                          ))}
                        </select>
                      </div>

                      {/* WYSIWYG Question Label */}
                      <div className="fb-question-wysiwyg-wrap">
                        <RichTextEditor
                          value={q.label}
                          onChange={(val) => updateQuestionLocal(qIdx, { label: val })}
                          variant="compact"
                          placeholder="Tulis pertanyaan di sini..."
                        />
                      </div>

                      {/* Options (for single_choice, checkbox, dropdown) */}
                      {hasOptions(q.type) && (
                        <div className="fb-options-list">
                          {(q.options || []).map((opt, oIdx) => (
                            <div key={opt.id || opt._tempId} className="fb-option-row">
                              {getOptionIndicator(q.type) && <div className={getOptionIndicator(q.type)} />}
                              {q.type === 'dropdown' && (
                                <span style={{ color: '#94a3b8', fontSize: '13px', minWidth: '20px' }}>{oIdx + 1}.</span>
                              )}
                              <input
                                className="fb-option-input"
                                type="text"
                                value={opt.label}
                                onChange={(e) => updateOptionLocal(qIdx, oIdx, { label: e.target.value })}
                                placeholder={`Opsi ${oIdx + 1}`}
                              />
                              {supportsCorrectAnswer(q.type) && (
                                <button
                                  className={`fb-correct-btn ${opt.is_correct ? 'active' : ''}`}
                                  onClick={() => markCorrectOption(qIdx, oIdx)}
                                  title={opt.is_correct ? 'Jawaban benar (klik untuk hapus)' : 'Tandai sebagai jawaban benar'}
                                  aria-label="Tandai sebagai jawaban benar"
                                >
                                  <svg width="15" height="15" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                                    <polyline points="20 6 9 17 4 12" />
                                  </svg>
                                </button>
                              )}
                              {q.options.length > 1 && (
                                <button
                                  className="fb-option-delete"
                                  onClick={() => removeOptionLocal(qIdx, oIdx)}
                                  aria-label="Hapus opsi"
                                >
                                  <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                    <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
                                  </svg>
                                </button>
                              )}
                            </div>
                          ))}

                          <div className="fb-add-option-row">
                            {getOptionIndicator(q.type) && <div className={getOptionIndicator(q.type)} style={{ opacity: 0.4 }} />}
                            <button className="fb-add-option-btn" onClick={() => addOptionToQuestion(qIdx)}>
                              Tambah opsi
                            </button>
                            <span style={{ color: '#cbd5e1', fontSize: '13px' }}>atau</span>
                            <button
                              className="fb-add-other-btn"
                              onClick={() => {
                                setQuestions((prev) =>
                                  prev.map((qq, i) =>
                                    i === qIdx
                                      ? {
                                          ...qq,
                                          _saved: false,
                                          options: [
                                            ...qq.options,
                                            {
                                              _tempId: `temp-opt-other-${Date.now()}`,
                                              label: 'Lainnya',
                                              value: '__other__',
                                              order_index: qq.options.length,
                                              is_correct: false,
                                            },
                                          ],
                                        }
                                      : qq
                                  )
                                );
                              }}
                            >
                              tambahkan &quot;Lainnya&quot;
                            </button>
                          </div>
                        </div>
                      )}

                      {/* Text placeholder for text type */}
                      {q.type === 'text' && (
                        <div style={{ marginTop: '8px' }}>
                          <input
                            style={{
                              width: '100%',
                              border: 'none',
                              borderBottom: '1px dashed #e2e8f0',
                              padding: '8px 0',
                              fontFamily: "'Inter', sans-serif",
                              fontSize: '14px',
                              color: '#cbd5e1',
                              outline: 'none',
                              background: 'transparent',
                            }}
                            type="text"
                            placeholder="Jawaban teks panjang..."
                            disabled
                          />
                        </div>
                      )}

                      {/* Date placeholder */}
                      {q.type === 'date' && (
                        <div style={{ marginTop: '8px' }}>
                          <input
                            style={{
                              width: '200px',
                              border: '1px solid #e2e8f0',
                              borderRadius: '8px',
                              padding: '8px 12px',
                              fontFamily: "'Inter', sans-serif",
                              fontSize: '14px',
                              color: '#cbd5e1',
                              outline: 'none',
                              background: '#fafbfc',
                            }}
                            type="date"
                            disabled
                          />
                        </div>
                      )}

                      {/* File upload placeholder */}
                      {q.type === 'file_upload' && (
                        <div
                          style={{
                            marginTop: '8px',
                            border: '2px dashed #e2e8f0',
                            borderRadius: '8px',
                            padding: '20px',
                            textAlign: 'center',
                            color: '#94a3b8',
                            fontSize: '13px',
                          }}
                        >
                          📎 Area upload file
                        </div>
                      )}

                      {/* Required note */}
                      {q.is_required && <p className="fb-required-note">* Wajib diisi</p>}

                      {/* Footer actions */}
                      <div className="fb-question-footer">
                        {/* Duplicate */}
                        <button className="fb-q-action-btn" onClick={() => duplicateQuestion(qIdx)} title="Duplikat">
                          <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <rect x="9" y="9" width="13" height="13" rx="2" />
                            <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1" />
                          </svg>
                        </button>
                        {/* Delete */}
                        <button className="fb-q-action-btn danger" onClick={(e) => { e.stopPropagation(); setConfirmSingleIdx(qIdx); }} title="Hapus">
                          <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <polyline points="3 6 5 6 21 6" />
                            <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                          </svg>
                        </button>
                        {/* Required toggle */}
                        <div className="fb-required-wrap">
                          <span className="fb-required-label">Wajib diisi</span>
                          <button
                            className={`fb-toggle ${q.is_required ? 'on' : 'off'}`}
                            onClick={() => updateQuestionLocal(qIdx, { is_required: !q.is_required })}
                            aria-label="Toggle required"
                          />
                        </div>
                      </div>
                    </div>
                  );
                })}

                {/* Add Question Button */}
                <button className="fb-add-question-btn" onClick={addQuestion}>
                  <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <circle cx="12" cy="12" r="10" />
                    <line x1="12" y1="8" x2="12" y2="16" />
                    <line x1="8" y1="12" x2="16" y2="12" />
                  </svg>
                  Tambah Pertanyaan
                </button>
              </div>

              {/* Floating actions */}
              <div className="fb-float-actions">
                <button className="fb-float-btn" onClick={addQuestion} title="Tambah pertanyaan">
                  <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path d="M4 7V4h16v3" /><path d="M9 20h6" /><path d="M12 4v16" />
                  </svg>
                </button>
              </div>
            </>
          )}

          {/* ===== SETTINGS TAB ===== */}
          {activeTab === 'setelan' && (
            <div className="fb-editor-area">
              <div className="fb-settings-card">
                <h2 className="fb-settings-title">Setelan Formulir</h2>

                {/* Slug */}
                <div className="fb-setting-group">
                  <label className="fb-setting-label">Slug URL</label>
                  <input
                    className="fb-setting-input"
                    type="text"
                    placeholder="slug-form-anda"
                    value={formData.slug}
                    onChange={(e) => setFormData((prev) => ({ ...prev, slug: e.target.value }))}
                    disabled={!!formData.id}
                  />
                  <p className="fb-slug-preview">
                    Link: {window.location.origin}/f/{formData.slug || 'slug-form-anda'}
                  </p>
                </div>

                {/* Status */}
                <div className="fb-setting-row">
                  <div>
                    <p className="fb-setting-row-label">Status</p>
                    <p className="fb-setting-row-desc">Status publikasi form</p>
                  </div>
                  <select
                    className="fb-status-select"
                    value={formData.status}
                    onChange={(e) => setFormData((prev) => ({ ...prev, status: e.target.value }))}
                  >
                    <option value="draft">Draft</option>
                    <option value="published">Published</option>
                    <option value="closed">Closed</option>
                  </select>
                </div>

                {/* Accept Responses */}
                <div className="fb-setting-row">
                  <div>
                    <p className="fb-setting-row-label">Terima Respons</p>
                    <p className="fb-setting-row-desc">Apakah form menerima jawaban baru</p>
                  </div>
                  <button
                    className={`fb-toggle ${formData.accept_responses ? 'on' : 'off'}`}
                    onClick={() => setFormData((prev) => ({ ...prev, accept_responses: !prev.accept_responses }))}
                  />
                </div>

                {/* Join Token */}
                <div className="fb-setting-row">
                  <div>
                    <p className="fb-setting-row-label">Token Ujian</p>
                    <p className="fb-setting-row-desc">Peserta harus memasukkan token untuk mengisi form</p>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    {formData.join_token && (
                      <code style={{ fontSize: '12px', background: '#f1f5f9', padding: '4px 8px', borderRadius: '6px', color: '#2563eb', fontWeight: 600 }}>
                        {formData.join_token}
                      </code>
                    )}
                    <button
                      className={`fb-toggle ${useJoinToken ? 'on' : 'off'}`}
                      onClick={() => setUseJoinToken(!useJoinToken)}
                      disabled={!!formData.id}
                    />
                  </div>
                </div>

                {/* ===== Mode Ujian / Keamanan ===== */}
                <div className="fb-settings-separator">
                  <span>Mode Ujian / Keamanan</span>
                </div>

                {/* Responden Lihat Hasil */}
                <div className="fb-setting-row">
                  <div>
                    <p className="fb-setting-row-label">Responden Lihat Hasil</p>
                    <p className="fb-setting-row-desc">Setelah submit, responden bisa melihat skor dan rincian jawaban</p>
                  </div>
                  <button
                    className={`fb-toggle ${formData.allow_see_result ? 'on' : 'off'}`}
                    onClick={() =>
                      setFormData((prev) => ({
                        ...prev,
                        allow_see_result: !prev.allow_see_result,
                        reveal_answers: !prev.allow_see_result ? prev.reveal_answers : false,
                      }))
                    }
                  />
                </div>

                {/* Tampilkan Kunci Jawaban */}
                <div className="fb-setting-row" style={{ opacity: formData.allow_see_result ? 1 : 0.45 }}>
                  <div>
                    <p className="fb-setting-row-label">Tampilkan Kunci Jawaban</p>
                    <p className="fb-setting-row-desc">Responden melihat jawaban yang benar di halaman hasil (aktif jika "Responden Lihat Hasil" menyala)</p>
                  </div>
                  <button
                    className={`fb-toggle ${formData.reveal_answers ? 'on' : 'off'}`}
                    onClick={() =>
                      setFormData((prev) => ({ ...prev, reveal_answers: !prev.reveal_answers }))
                    }
                    disabled={!formData.allow_see_result}
                  />
                </div>

                {/* Batas Pengisian */}
                <div className="fb-setting-row">
                  <div>
                    <p className="fb-setting-row-label">Batas Pengisian</p>
                    <p className="fb-setting-row-desc">Berapa kali responden boleh mengirimkan jawaban</p>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <select
                      className="fb-status-select"
                      style={{ width: '150px' }}
                      value={maxSubmissionsMode}
                      onChange={(e) => {
                        const mode = e.target.value;
                        setMaxSubmissionsMode(mode);
                        if (mode === 'once') setFormData((prev) => ({ ...prev, max_submissions: 1 }));
                        if (mode === 'unlimited') setFormData((prev) => ({ ...prev, max_submissions: 0 }));
                        if (mode === 'custom') setFormData((prev) => ({ ...prev, max_submissions: customMaxSubmissions }));
                      }}
                    >
                      <option value="once">1 kali</option>
                      <option value="unlimited">Tidak terbatas</option>
                      <option value="custom">Custom</option>
                    </select>
                    {maxSubmissionsMode === 'custom' && (
                      <input
                        className="fb-setting-input"
                        style={{ width: '80px' }}
                        type="number"
                        min="2"
                        value={customMaxSubmissions}
                        onChange={(e) => {
                          const val = Math.max(2, parseInt(e.target.value, 10) || 2);
                          setCustomMaxSubmissions(val);
                          setFormData((prev) => ({ ...prev, max_submissions: val }));
                        }}
                      />
                    )}
                  </div>
                </div>

                {/* Mode Full Screen */}
                <div className="fb-setting-row">
                  <div>
                    <p className="fb-setting-row-label">Mode Full Screen</p>
                    <p className="fb-setting-row-desc">Responden wajib mengisi dalam mode full screen; keluar = ditandai curang</p>
                  </div>
                  <button
                    className={`fb-toggle ${formData.require_fullscreen ? 'on' : 'off'}`}
                    onClick={() => setFormData((prev) => ({ ...prev, require_fullscreen: !prev.require_fullscreen }))}
                  />
                </div>
                {formData.require_fullscreen && (
                  <div className="fb-info-box warning">
                    <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                    </svg>
                    <span>Peringatan: jika responden keluar dari mode full screen, submission akan ditandai sebagai curang (is_cheated).</span>
                  </div>
                )}

                {/* Semua Pertanyaan Wajib Diisi — bulk */}
                <div className="fb-setting-row">
                  <div>
                    <p className="fb-setting-row-label">Semua Pertanyaan Wajib Diisi</p>
                    <p className="fb-setting-row-desc">
                      {questions.length === 0
                        ? 'Tambah soal dulu untuk mengatur'
                        : `${questions.filter((q) => q.is_required).length}/${questions.length} soal wajib • Aktifkan untuk mewajibkan semua sekaligus`}
                    </p>
                  </div>
                  <button
                    className={`fb-toggle ${allRequired ? 'on' : 'off'}`}
                    onClick={() => setAllRequired(!allRequired)}
                    disabled={questions.length === 0}
                    aria-label="Toggle semua wajib diisi"
                    title={questions.length === 0 ? 'Tambah soal dulu' : allRequired ? 'Jadikan semua tidak wajib' : 'Jadikan semua wajib'}
                  />
                </div>

                {/* Date Range */}
                <div className="fb-setting-group" style={{ marginTop: '22px' }}>
                  <label className="fb-setting-label">Jadwal Buka/Tutup</label>
                  <div className="fb-date-inputs">
                    <div>
                      <label className="fb-setting-label" style={{ fontSize: '11px', color: '#94a3b8' }}>Mulai</label>
                      <input
                        className="fb-setting-input"
                        type="datetime-local"
                        value={formData.start_date}
                        onChange={(e) => setFormData((prev) => ({ ...prev, start_date: e.target.value }))}
                      />
                    </div>
                    <div>
                      <label className="fb-setting-label" style={{ fontSize: '11px', color: '#94a3b8' }}>Selesai</label>
                      <input
                        className="fb-setting-input"
                        type="datetime-local"
                        value={formData.end_date}
                        onChange={(e) => setFormData((prev) => ({ ...prev, end_date: e.target.value }))}
                      />
                    </div>
                  </div>
                </div>

                {/* QR Code */}
                <div className="fb-setting-row" style={{ borderBottom: 'none', marginTop: '8px' }}>
                  <div>
                    <p className="fb-setting-row-label">QR Code</p>
                    <p className="fb-setting-row-desc">Generate QR code untuk dibagikan</p>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    {formData.qr_code_url && (
                      <button
                        type="button"
                        className="fb-qr-btn"
                        style={{ background: '#f1f5f9', color: '#334155', border: '1px solid #cbd5e1' }}
                        onClick={() => setShowQrModal(true)}
                      >
                        Lihat QR
                      </button>
                    )}
                    <button className="fb-qr-btn" onClick={handleGenerateQR} disabled={!formData.id}>
                      {formData.qr_code_url ? 'Regenerate QR' : 'Generate QR'}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}
        </section>
      </main>

      {/* Import Word Modal — Premium */}
      {showImportModal && (
        <div className="fb-import-modal-overlay" onClick={resetImportModal}>
          <div className="fb-import-modal" onClick={(e) => e.stopPropagation()}>
            {/* Header — gradient hero */}
            <div className="fb-import-modal-header">
              <div className="fb-import-header-left">
                <div className="fb-import-header-icon">
                  <svg width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
                    <polyline points="14 2 14 8 20 8" />
                    <line x1="12" y1="18" x2="12" y2="12" />
                    <polyline points="9 15 12 18 15 15" />
                  </svg>
                </div>
                <div className="fb-import-header-text">
                  <h3>Import Soal dari Word</h3>
                  <p>Upload file .docx — otomatis jadi soal pilihan ganda</p>
                </div>
              </div>
              <button className="fb-import-close-btn" onClick={resetImportModal} aria-label="Tutup">
                <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              </button>
            </div>

            {/* Stepper */}
            <div className="fb-import-stepper">
              <div className={`fb-import-step ${importPhase === 'upload' ? 'active' : importPhase === 'preview' || importPhase === 'importing' ? 'done' : ''}`}>
                <span className="fb-import-step-num">{importPhase === 'preview' || importPhase === 'importing' ? '✓' : '1'}</span>
                Template &amp; Upload
              </div>
              <div className={`fb-import-step-line ${importPhase === 'preview' || importPhase === 'importing' ? 'filled' : ''}`} />
              <div className={`fb-import-step ${importPhase === 'preview' ? 'active' : importPhase === 'importing' ? 'done' : ''}`}>
                <span className="fb-import-step-num">{importPhase === 'importing' ? '✓' : '2'}</span>
                Preview &amp; Import
              </div>
            </div>

            {/* Body */}
            <div className="fb-import-modal-body">
              {/* ===== PHASE: UPLOAD ===== */}
              {importPhase === 'upload' && (
                <>
                  {/* Template download — premium card */}
                  <div className="fb-import-template-card">
                    <div className="fb-import-template-icon">
                      <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
                        <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" fill="white" opacity="0.95" />
                        <path d="M14 2v6h6" fill="#bfdbfe" />
                      </svg>
                      <span>DOCX</span>
                    </div>
                    <div className="fb-import-template-info">
                      <strong>Template Word (.docx)</strong>
                      <span>Download, isi 2–8 opsi per soal, lalu upload kembali</span>
                    </div>
                    <button className="fb-import-download-btn" onClick={handleDownloadTemplate}>
                      <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.2}>
                        <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" />
                        <polyline points="7 10 12 15 17 10" />
                        <line x1="12" y1="15" x2="12" y2="3" />
                      </svg>
                      Download Template
                    </button>
                  </div>

                  {/* Guide — premium cards */}
                  <div className="fb-import-guide">
                    <div className="fb-import-guide-head">
                      <strong>
                        <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <circle cx="12" cy="12" r="10" /><path d="M12 16v-4M12 8h.01" />
                        </svg>
                        Cara Penulisan di Word
                      </strong>
                      <small>Khusus Pilihan Ganda</small>
                    </div>
                    <div className="fb-import-guide-grid">
                      <div className="fb-import-guide-item">
                        <span className="fb-import-guide-num">1</span>
                        <p>Soal diawali nomor<br /><span>1. Ibu kota Indonesia adalah ...</span></p>
                      </div>
                      <div className="fb-import-guide-item">
                        <span className="fb-import-guide-num">2</span>
                        <p>Opsi pakai huruf<br /><span>A. Bandung</span> &nbsp; <span>B. Jakarta</span></p>
                      </div>
                      <div className="fb-import-guide-item">
                        <span className="fb-import-guide-num">★</span>
                        <p>Kunci cara 1 — bintang<br /><em>*B. Jakarta</em> &nbsp; di depan opsi benar</p>
                      </div>
                      <div className="fb-import-guide-item">
                        <span className="fb-import-guide-num">✎</span>
                        <p>Kunci cara 2 — baris kunci<br /><span>Jawaban: B</span> &nbsp; setelah semua opsi</p>
                      </div>
                    </div>
                    <div className="fb-import-guide-foot">
                      <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path d="M12 9v3m0 4h.01M10.3 3.3L3.3 10.3a1.5 1.5 0 000 2.12l6.99 6.99a1.5 1.5 0 002.12 0l6.99-6.99a1.5 1.5 0 000-2.12L12.4 3.3a1.5 1.5 0 00-2.12 0z" />
                      </svg>
                      Simpan sebagai <strong>.docx</strong> (bukan .doc lama) — maksimal 8 opsi &amp; 5 MB
                    </div>
                  </div>

                  {/* Error */}
                  {importError && (
                    <div className="fb-import-error-banner">
                      <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <circle cx="12" cy="12" r="10" /><line x1="12" y1="8" x2="12" y2="12" /><line x1="12" y1="16" x2="12.01" y2="16" />
                      </svg>
                      <span>{importError}</span>
                    </div>
                  )}

                  {/* Dropzone — premium */}
                  <div
                    className={`fb-import-dropzone ${importDragging ? 'dragging' : ''}`}
                    onDrop={handleImportDrop}
                    onDragOver={handleImportDragOver}
                    onDragLeave={handleImportDragLeave}
                    onClick={() => document.getElementById('fb-import-file-input')?.click()}
                  >
                    {importLoading ? (
                      <div className="fb-import-loading">
                        <div className="fb-import-loading-card">
                          <div className="db-spinner" />
                        </div>
                        <span className="fb-import-loading-text">
                          Memproses file...
                          <small>Menganalisis soal &amp; kunci jawaban</small>
                        </span>
                      </div>
                    ) : (
                      <>
                        <div className="fb-import-dropzone-icon">
                          <svg width="26" height="26" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.6}>
                            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
                            <polyline points="14 2 14 8 20 8" />
                            <line x1="12" y1="18" x2="12" y2="12" />
                            <polyline points="9 15 12 18 15 15" />
                          </svg>
                        </div>
                        <div className="fb-import-dropzone-text">
                          <strong>Klik untuk upload</strong> atau seret file ke sini
                        </div>
                        <div className="fb-import-dropzone-hint">.docx • Maks. 5 MB • Drag &amp; drop didukung</div>
                      </>
                    )}
                    <input
                      id="fb-import-file-input"
                      type="file"
                      accept=".docx"
                      onChange={(e) => handleFileSelect(e.target.files?.[0])}
                    />
                  </div>
                </>
              )}

              {/* ===== PHASE: PREVIEW ===== */}
              {importPhase === 'preview' && importPreview && (
                <>
                  {/* Stats — premium cards */}
                  <div className="fb-import-stats">
                    <div className="fb-import-stat total">
                      <div className="fb-import-stat-icon">
                        <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" /><polyline points="14 2 14 8 20 8" /><line x1="16" y1="13" x2="8" y2="13" /><line x1="16" y1="17" x2="8" y2="17" />
                        </svg>
                      </div>
                      <div className="fb-import-stat-text">
                        <strong>{importPreview.total}</strong>
                        <span>Total Soal</span>
                      </div>
                    </div>
                    <div className="fb-import-stat valid">
                      <div className="fb-import-stat-icon">
                        <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.2}>
                          <path d="M20 6L9 17l-5-5" />
                        </svg>
                      </div>
                      <div className="fb-import-stat-text">
                        <strong>{importPreview.valid_count}</strong>
                        <span>Valid</span>
                      </div>
                    </div>
                    <div className="fb-import-stat error">
                      <div className="fb-import-stat-icon">
                        <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <circle cx="12" cy="12" r="10" /><line x1="12" y1="8" x2="12" y2="12" /><line x1="12" y1="16" x2="12.01" y2="16" />
                        </svg>
                      </div>
                      <div className="fb-import-stat-text">
                        <strong>{importPreview.total - importPreview.valid_count}</strong>
                        <span>Error</span>
                      </div>
                    </div>
                  </div>

                  {/* File badge */}
                  <div className="fb-import-file-badge">
                    <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" /><polyline points="14 2 14 8 20 8" />
                    </svg>
                    <span><strong>{importFile?.name}</strong> • {(importFile?.size / 1024).toFixed(0)} KB</span>
                    <button
                      onClick={() => { setImportPhase('upload'); setImportPreview(null); setImportFile(null); setImportError(null); }}
                      style={{ marginLeft: 'auto', background: '#fff', border: '1px solid #e2e8f0', borderRadius: '6px', padding: '3px 8px', fontSize: '11px', fontWeight: 600, color: '#64748b', cursor: 'pointer' }}
                    >
                      Ganti file
                    </button>
                  </div>

                  {/* Select All */}
                  {importPreview.valid_count > 0 && (
                    <div className="fb-import-select-all">
                      <label>
                        <input
                          type="checkbox"
                          checked={importSelected.size === importPreview.valid_count}
                          onChange={toggleImportSelectAll}
                        />
                        Pilih semua soal valid
                      </label>
                      <span className="fb-import-select-count">{importSelected.size} / {importPreview.valid_count} dipilih</span>
                    </div>
                  )}

                  {/* Question List — premium */}
                  <div className="fb-import-question-list">
                    {importPreview.questions.map((q) => (
                      <div key={q.number} className={`fb-import-q-item ${q.errors.length === 0 ? 'valid' : 'error'}`}>
                        <input
                          type="checkbox"
                          checked={importSelected.has(q.number)}
                          disabled={q.errors.length > 0}
                          onChange={() => toggleImportQuestion(q.number)}
                        />
                        <div className="fb-import-q-content">
                          <span className="fb-import-q-num">Soal {q.number} {q.errors.length === 0 ? '• Valid' : '• Error'}</span>
                          <div className="fb-import-q-label">{q.label}</div>
                          {q.options.length > 0 && (
                            <div className="fb-import-q-options">
                              {q.options.map((o, i) => (
                                <span key={i} className={`fb-import-q-opt ${o.is_correct ? 'correct' : ''}`}>
                                  {String.fromCharCode(65 + o.order_index)}. {o.label}{o.is_correct ? ' ★' : ''}
                                </span>
                              ))}
                            </div>
                          )}
                          {q.errors.length > 0 && (
                            <div className="fb-import-q-errors">
                              {q.errors.map((err, i) => (
                                <span key={i} className="fb-import-q-error-tag">
                                  <svg width="10" height="10" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}><line x1="12" y1="8" x2="12" y2="12" /><line x1="12" y1="16" x2="12.01" y2="16" /></svg>
                                  {err}
                                </span>
                              ))}
                            </div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>

                  {importPreview.valid_count === 0 && (
                    <div style={{ textAlign: 'center', padding: '28px 16px', color: '#64748b', fontSize: '13px', background: '#f8fafc', border: '1px dashed #cbd5e1', borderRadius: '12px', marginTop: '10px' }}>
                      <div style={{ fontSize: '22px', marginBottom: '6px' }}>😕</div>
                      <strong style={{ color: '#334155' }}>Tidak ada soal valid</strong><br />
                      Periksa format penulisan — pastikan ada nomor soal &amp; opsi A/B/C/D
                    </div>
                  )}
                </>
              )}

              {/* ===== PHASE: IMPORTING ===== */}
              {importPhase === 'importing' && (
                <div className="fb-import-loading">
                  <div className="fb-import-loading-card">
                    <div className="db-spinner" />
                  </div>
                  <span className="fb-import-loading-text">
                    Mengimpor {importSelected.size} soal...
                    <small>Mohon tunggu, jangan tutup halaman</small>
                  </span>
                </div>
              )}
            </div>

            {/* Footer */}
            <div className="fb-import-modal-footer">
              <span className="fb-import-footer-hint">
                {importPhase === 'upload' ? 'Butuh bantuan? Lihat template Word' : importPhase === 'preview' ? `${importSelected.size} soal siap diimpor` : 'Sedang memproses...'}
              </span>
              <div style={{ display: 'flex', gap: '8px', marginLeft: 'auto' }}>
                <button className="fb-import-cancel-btn" onClick={resetImportModal}>
                  {importPhase === 'preview' ? 'Batal' : 'Tutup'}
                </button>
                {importPhase === 'preview' && (
                  <button
                    className="fb-import-confirm-btn"
                    onClick={handleImportConfirm}
                    disabled={importSelected.size === 0 || importLoading}
                  >
                    <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.2}><path d="M20 6L9 17l-5-5" /></svg>
                    Import {importSelected.size} Soal
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* QR Code Modal Pop-up */}
      {showQrModal && formData.qr_code_url && (
        <div className="fb-modal-overlay" onClick={() => setShowQrModal(false)}>
          <div className="fb-modal-card" onClick={(e) => e.stopPropagation()}>
            <button className="fb-modal-close" onClick={() => setShowQrModal(false)} aria-label="Tutup">
              <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>

            <h3 className="fb-modal-title">QR Code Formulir</h3>
            <p className="fb-modal-subtitle">Pindai kode QR untuk membuka formulir ini di perangkat seluler</p>

            <div className="fb-qr-img-wrapper">
              <NgrokImage src={formData.qr_code_url} alt="QR Code Form" style={{ width: '190px', height: '190px', display: 'block' }} />
            </div>

            <div className="fb-share-link-box">
              <span className="fb-share-link-text">{getPublicLink()}</span>
              <button className={`fb-copy-btn ${copiedLink ? 'copied' : ''}`} onClick={handleCopyLink}>
                {copiedLink ? 'Tersalin!' : 'Salin Link'}
              </button>
            </div>

            <div className="fb-modal-actions">
              <button
                onClick={async () => {
                  try {
                    const res = await apiFetch(formData.qr_code_url);
                    if (!res.ok) throw new Error('Gagal fetch QR');
                    const blob = await res.blob();
                    const url = window.URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = `qrcode-${formData.slug}.png`;
                    document.body.appendChild(a);
                    a.click();
                    a.remove();
                    window.URL.revokeObjectURL(url);
                  } catch (e) {
                    window.open(formData.qr_code_url, '_blank');
                  }
                }}
                className="fb-modal-btn secondary"
              >
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" />
                  <polyline points="7 10 12 15 17 10" />
                  <line x1="12" y1="15" x2="12" y2="3" />
                </svg>
                Unduh QR
              </button>
              <a
                href={getPublicLink()}
                target="_blank"
                rel="noopener noreferrer"
                className="fb-modal-btn primary"
                style={{ textDecoration: 'none' }}
              >
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6" />
                  <polyline points="15 3 21 3 21 9" />
                  <line x1="10" y1="14" x2="21" y2="3" />
                </svg>
                Buka Form
              </a>
            </div>
          </div>
        </div>
      )}

      {/* Bulk Delete Confirm — Premium Modal */}
      {showBulkConfirm && (
        <div className="fb-confirm-overlay" onClick={() => !bulkDeleting && setShowBulkConfirm(false)}>
          <div className="fb-confirm-card" onClick={(e) => e.stopPropagation()}>
            <button className="fb-confirm-close" onClick={() => !bulkDeleting && setShowBulkConfirm(false)} disabled={bulkDeleting} aria-label="Tutup">
              <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
            </button>
            <div className="fb-confirm-icon danger">
              <svg width="28" height="28" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                <polyline points="3 6 5 6 21 6" />
                <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                <line x1="10" y1="11" x2="10" y2="17" />
                <line x1="14" y1="11" x2="14" y2="17" />
              </svg>
            </div>
            <h3 className="fb-confirm-title">
              {bulkSelected.size === questions.length ? 'Hapus Semua Soal?' : `Hapus ${bulkSelected.size} Soal Terpilih?`}
            </h3>
            <p className="fb-confirm-desc">
              {bulkSelected.size === questions.length ? (
                <>Kamu akan menghapus <strong>semua {bulkSelected.size} soal</strong> di form ini. Semua pertanyaan dan kunci jawaban akan hilang permanen.</>
              ) : (
                <>Kamu akan menghapus <strong>{bulkSelected.size} soal terpilih</strong>. Tindakan ini tidak bisa dibatalkan.</>
              )}
            </p>
            <div className="fb-confirm-actions">
              <button className="fb-confirm-btn secondary" onClick={() => setShowBulkConfirm(false)} disabled={bulkDeleting}>Batal</button>
              <button className="fb-confirm-btn danger" onClick={executeBulkDelete} disabled={bulkDeleting}>
                {bulkDeleting ? (
                  <>
                    <span className="fb-confirm-spinner" />
                    Menghapus...
                  </>
                ) : (
                  <>
                    <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><polyline points="3 6 5 6 21 6" /><path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" /></svg>
                    Ya, Hapus
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Single Delete Confirm — Premium Modal */}
      {confirmSingleIdx !== null && (
        <div className="fb-confirm-overlay" onClick={() => setConfirmSingleIdx(null)}>
          <div className="fb-confirm-card small" onClick={(e) => e.stopPropagation()}>
            <button className="fb-confirm-close" onClick={() => setConfirmSingleIdx(null)} aria-label="Tutup">
              <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
            </button>
            <div className="fb-confirm-icon danger small">
              <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                <polyline points="3 6 5 6 21 6" />
                <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
              </svg>
            </div>
            <h3 className="fb-confirm-title">Hapus Soal Ini?</h3>
            <p className="fb-confirm-desc">
              Soal <strong>Pertanyaan {confirmSingleIdx + 1}</strong> akan dihapus permanen dan tidak bisa dikembalikan.
            </p>
            <div className="fb-confirm-actions">
              <button className="fb-confirm-btn secondary" onClick={() => setConfirmSingleIdx(null)}>Batal</button>
              <button className="fb-confirm-btn danger" onClick={executeSingleDelete}>
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><polyline points="3 6 5 6 21 6" /><path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" /></svg>
                Hapus
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Confirm Save as Template — FIX: konfirmasi dulu, bukan langsung terload saat refresh */}
      {showConfirmTemplateSave && (
        <div className="fb-confirm-overlay" onClick={() => setShowConfirmTemplateSave(false)}>
          <div className="fb-confirm-card" onClick={(e) => e.stopPropagation()}>
            <button className="fb-confirm-close" onClick={() => setShowConfirmTemplateSave(false)} aria-label="Tutup">
              <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
            </button>
            <div className="fb-confirm-icon" style={{ background: '#eff6ff', color: '#2563eb' }}>
              <svg width="28" height="28" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}><rect x="3" y="3" width="18" height="18" rx="2" /><path d="M3 9h18M9 21V9" /></svg>
            </div>
            <h3 className="fb-confirm-title">Simpan sebagai Template?</h3>
            <p className="fb-confirm-desc">
              Template <strong>{formData.title || 'Tanpa Judul'}</strong> dengan <strong>{questions.length} soal</strong> akan disimpan dan langsung muncul di <strong>Dashboard &gt; Template</strong> tanpa perlu refresh.
            </p>
            <div className="fb-confirm-actions">
              <button className="fb-confirm-btn secondary" onClick={() => setShowConfirmTemplateSave(false)}>Batal</button>
              <button className="fb-confirm-btn primary" onClick={confirmSaveAsTemplate} disabled={templateSaving} style={{ background: '#2563eb', color: 'white' }}>
                {templateSaving ? 'Menyimpan...' : 'Ya, Simpan'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Toast */}
      {toast && (
        <div className={`fb-toast ${toast.type === 'error' ? 'error' : toast.type === 'success' ? 'success' : ''}`}>
          {toast.msg}
        </div>
      )}
    </div>
  );
}

