import { useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { getMe, logout } from '../api/auth';
import { createForm } from '../api/forms';
import { generateAiForm } from '../api/ai';
import { getValidToken } from '../utils/authStorage';
import { prepareMathHtml } from '../utils/mathRender';
import ThemeToggle from '../components/ThemeToggle';
import logoForm4x from '../assets/logo_form4x.png';
import '../styles/ai-builder.css';

const QUESTION_TYPE_LABELS = {
  text: 'Teks',
  paragraph: 'Paragraf',
  single_choice: 'Pilihan Ganda',
  checkbox: 'Checkbox',
  dropdown: 'Dropdown',
  date: 'Tanggal',
  file_upload: 'Upload File',
  page_break: 'Bagian',
};

function stripHtml(html) {
  if (!html) return '';
  return String(html).replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

export default function AiFormBuilderPage() {
  const navigate = useNavigate();
  const token = getValidToken() || localStorage.getItem('token');

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [prompt, setPrompt] = useState('');
  const [numQuestions, setNumQuestions] = useState(10);
  const [includeCorrect, setIncludeCorrect] = useState(true);
  const [useSections, setUseSections] = useState(true);
  const [isGenerating, setIsGenerating] = useState(false);
  const [preview, setPreview] = useState(null);
  const [error, setError] = useState('');
  const [toast, setToast] = useState(null);

  const showToast = useCallback((msg, type = 'info') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  }, []);

  const handleGenerate = async () => {
    if (!prompt.trim() || prompt.trim().length < 10) {
      setError('Prompt minimal 10 karakter. Contoh: “Buatkan ujian matematika kelas 10, 2 Bagian: biodata & 10 soal aljabar pilihan ganda dengan kunci jawaban”');
      return;
    }
    if (numQuestions < 3 || numQuestions > 30) {
      setError('Jumlah soal harus 3-30');
      return;
    }
    setError('');
    setIsGenerating(true);
    setPreview(null);
    try {
      const data = await generateAiForm(token, {
        title: title.trim() || undefined,
        description: description.trim() || undefined,
        prompt: prompt.trim(),
        num_questions: Number(numQuestions),
        include_correct: includeCorrect,
        use_sections: useSections,
      });
      setPreview(data);
      showToast('Form berhasil digenerate AI!', 'success');
    } catch (err) {
      setError(err.message || 'Gagal generate form');
      showToast(err.message || 'Gagal generate', 'error');
    } finally {
      setIsGenerating(false);
    }
  };

  const handleRegenerate = () => {
    handleGenerate();
  };

  const handleConfirm = async () => {
    if (!preview) return;
    try {
      setIsGenerating(true);
      const payload = {
        title: preview.title || title || 'Form Buatan AI',
        description: preview.description || description || '',
        slug: '', // backend will generate
        questions: (preview.questions || []).map((q, idx) => ({
          type: q.type,
          label: q.label,
          placeholder: q.placeholder || '',
          is_required: !!q.is_required,
          order_index: idx,
          settings: q.settings || {},
          options: (q.options || []).map((o, oidx) => ({
            label: o.label,
            value: o.label,
            order_index: oidx,
            is_correct: !!o.is_correct,
          })),
        })),
        use_join_token: false,
        status: 'draft',
      };
      // gunakan createForm
      const created = await createForm(token, {
        title: payload.title,
        description: payload.description,
        slug: `ai-${Date.now().toString(36)}-${Math.random().toString(36).slice(2,6)}`,
        questions: payload.questions,
        status: 'draft',
        allow_see_result: false,
        max_submissions: 0,
        require_fullscreen: false,
        reveal_answers: includeCorrect,
      });
      showToast('Form disimpan! Mengalihkan ke editor...', 'success');
      setTimeout(() => navigate(`/form-builder/${created.id}`), 800);
    } catch (err) {
      showToast(err.message || 'Gagal menyimpan form', 'error');
    } finally {
      setIsGenerating(false);
    }
  };

  const handleBack = () => navigate('/dashboard');

  // group preview questions into sections for display
  const previewSections = (() => {
    if (!preview?.questions) return [];
    const qs = preview.questions;
    const sections = [];
    let cur = { pb: null, questions: [] };
    qs.forEach((q) => {
      if (q.type === 'page_break') {
        if (cur.questions.length > 0 || cur.pb) {
          sections.push(cur);
          cur = { pb: q, questions: [] };
        } else {
          cur.pb = q;
        }
      } else {
        cur.questions.push(q);
      }
    });
    sections.push(cur);
    return sections;
  })();

  return (
    <div className="ai-root">
      {/* Ambient Wave Background Effect */}
      <div className="ai-bg-waves" aria-hidden="true">
        <div className="ai-glow-orb orb-1" />
        <div className="ai-glow-orb orb-2" />
        <svg className="ai-wave-svg wave-1" viewBox="0 0 1440 320" preserveAspectRatio="none">
          <path fill="currentColor" d="M0,192L48,176C96,160,192,128,288,138.7C384,149,480,203,576,213.3C672,224,768,192,864,165.3C960,139,1056,117,1152,128C1248,139,1344,181,1392,202.7L1440,224L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z" />
        </svg>
        <svg className="ai-wave-svg wave-2" viewBox="0 0 1440 320" preserveAspectRatio="none">
          <path fill="currentColor" d="M0,96L48,122.7C96,149,192,203,288,208C384,213,480,171,576,144C672,117,768,107,864,128C960,149,1056,203,1152,213.3C1248,224,1344,160,1392,128L1440,96L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z" />
        </svg>
      </div>

      <header className="ai-header">
        <div className="ai-header-left">
          <button className="ai-back-btn" onClick={handleBack} aria-label="Kembali ke Dashboard" title="Kembali ke Dashboard">
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}><polyline points="15 18 9 12 15 6" /></svg>
          </button>
          <img src={logoForm4x} alt="Formax Logo" className="ai-logo" />
          <div className="ai-brand-wrap">
            <div className="ai-title-row">
              <h1 className="ai-title">Formax AI</h1>
              <span className="ai-badge-chip">AI Generator</span>
            </div>
            <p className="ai-subtitle">Buat form otomatis cerdas — berikan prompt, sistem susun soal & bagian secara instan</p>
          </div>
        </div>
        <div className="ai-header-right">
          <ThemeToggle />
        </div>
      </header>

      <main className="ai-main">
        <div className="ai-grid">
          {/* LEFT: Input Configuration */}
          <section className="ai-card ai-input-card">
            <div className="ai-card-header">
              <div className="ai-card-icon-wrap">
                <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456z" />
                </svg>
              </div>
              <div>
                <h2 className="ai-card-title">Prompt AI</h2>
                <p className="ai-card-desc">Jelaskan instruksi form. AI akan menyusun judul, deskripsi, soal, pilihan jawaban, hingga struktur bagian (section).</p>
              </div>
            </div>

            <div className="ai-form-group">
              <label className="ai-label">Judul Form <span className="ai-optional">(opsional, dapat diisi otomatis oleh AI)</span></label>
              <input className="ai-input" type="text" placeholder="Contoh: Ujian Matematika Kelas 10 — Aljabar" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={120} />
            </div>

            <div className="ai-form-group">
              <label className="ai-label">Deskripsi Form <span className="ai-optional">(opsional)</span></label>
              <textarea className="ai-textarea" rows={2} placeholder="Contoh: Ujian pengukur pemahaman aljabar dasar, durasi 60 menit..." value={description} onChange={(e) => setDescription(e.target.value)} maxLength={2000} />
            </div>

            <div className="ai-form-group">
              <label className="ai-label">Instruksi / Prompt AI <span className="ai-required">*</span></label>
              <textarea className="ai-textarea ai-prompt" rows={5} placeholder="Contoh: Buatkan ujian Matematika kelas 10, 2 Bagian: Bagian 1 Biodata (nama, kelas, email) dan Bagian 2 berisi 10 soal pilihan ganda tentang aljabar (persamaan linear, kuadrat) dengan 4 opsi dan kunci jawaban. Soal di Bagian 2 diacak per siswa." value={prompt} onChange={(e) => setPrompt(e.target.value)} maxLength={4000} />
              <div className="ai-char-count">{prompt.length} / 4000 karakter</div>
            </div>

            <div className="ai-form-group">
              <label className="ai-label">Target Jumlah Soal</label>
              <div className="ai-num-row">
                <input type="range" min={3} max={30} value={numQuestions} onChange={(e) => setNumQuestions(Number(e.target.value))} className="ai-range" />
                <div className="ai-num-badge">{numQuestions} Soal</div>
              </div>
              <span className="ai-hint">Kisaran 3-30 soal (rekomendasi: 10)</span>
            </div>

            <div className="ai-toggles">
              <label className="ai-toggle-row">
                <div className="ai-toggle-info">
                  <span className="ai-toggle-title">Kunci Jawaban Otomatis</span>
                  <span className="ai-toggle-sub">AI menandai opsi benar untuk soal pilihan ganda</span>
                </div>
                <button type="button" className={`ai-toggle ${includeCorrect ? 'on' : 'off'}`} onClick={() => setIncludeCorrect((v) => !v)} aria-label="Toggle kunci jawaban">
                  <span className="ai-toggle-slider" />
                </button>
              </label>

              <label className="ai-toggle-row">
                <div className="ai-toggle-info">
                  <span className="ai-toggle-title">Gunakan Bagian (Section)</span>
                  <span className="ai-toggle-sub">Gunakan pemisah halaman (Bagian 1, 2, dst)</span>
                </div>
                <button type="button" className={`ai-toggle ${useSections ? 'on' : 'off'}`} onClick={() => setUseSections((v) => !v)} aria-label="Toggle bagian">
                  <span className="ai-toggle-slider" />
                </button>
              </label>
            </div>

            <div className="ai-billing-hint">
              <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" /></svg>
              <span>Model: <strong>Gemini 1.5 Flash</strong> — proses cepat, responsif, dan hemat penggunaan token kuota.</span>
            </div>

            {error && (
              <div className="ai-error">
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
                <span>{error}</span>
              </div>
            )}

            <button className="ai-generate-btn" onClick={handleGenerate} disabled={isGenerating || !prompt.trim()}>
              {isGenerating ? (
                <>
                  <span className="ai-btn-spinner" />
                  Generating Form...
                </>
              ) : (
                <>
                  <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.2}><path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" /></svg>
                  Generate Form Sekarang
                </>
              )}
            </button>
            <p className="ai-generate-hint">Mendukung Bahasa Indonesia &amp; Inggris secara otomatis</p>
          </section>

          {/* RIGHT: Live Preview */}
          <section className="ai-card ai-preview-card">
            <div className="ai-preview-header">
              <div className="ai-card-header" style={{ marginBottom: 0 }}>
                <div className="ai-card-icon-wrap preview-icon">
                  <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                    <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                </div>
                <div>
                  <h2 className="ai-card-title">Preview Hasil Form</h2>
                  <p className="ai-card-desc">Review struktur form yang telah dibuat AI sebelum disimpan ke editor.</p>
                </div>
              </div>
              {preview && (
                <span className="ai-preview-count">
                  {preview.questions.filter((q)=>q.type!=='page_break').length} Soal &bull; {previewSections.length} Bagian
                </span>
              )}
            </div>

            {isGenerating && (
              <div className="ai-loading">
                <div className="ai-orb-wrap">
                  <div className="ai-orb" />
                  <div className="ai-orb-ring" />
                  <div className="ai-orb-ring delay" />
                </div>
                <div className="ai-loading-text">
                  <strong>Formax AI sedang meracik form...</strong>
                  <span>Menganalisis instruksi &amp; menyusun struktur pertanyaan</span>
                </div>
                <div className="ai-loading-shimmer">
                  <div className="ai-shimmer-line w-80" />
                  <div className="ai-shimmer-line w-60" />
                  <div className="ai-shimmer-line w-90" />
                </div>
                <div className="ai-loading-dots"><span /><span /><span /></div>
              </div>
            )}

            {!isGenerating && !preview && (
              <div className="ai-empty">
                <div className="ai-empty-icon-wrap">
                  <svg width="48" height="48" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
                  </svg>
                </div>
                <p>Belum ada preview form</p>
                <small>Tuliskan instruksi pada panel di sebelah kiri, kemudian klik tombol <strong>Generate Form Sekarang</strong> untuk melihat hasilnya.</small>
              </div>
            )}

            {!isGenerating && preview && (
              <div className="ai-preview-content">
                <div className="ai-preview-form-header">
                  <h3 className="ai-preview-title" dangerouslySetInnerHTML={{ __html: preview.title }} />
                  {preview.description && <p className="ai-preview-desc" dangerouslySetInnerHTML={{ __html: preview.description }} />}
                </div>

                {previewSections.map((sec, sIdx) => (
                  <div key={sIdx} className="ai-preview-section">
                    {sec.pb && (
                      <div className="ai-preview-section-header">
                        <div className="ai-preview-section-top">
                          <span className="ai-preview-badge">Bagian {sIdx + 1}</span>
                          {sec.pb.settings?.shuffle && (
                            <span className="ai-preview-shuffle">
                              <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" /></svg>
                              Diacak per responden
                            </span>
                          )}
                        </div>
                        <h4 className="ai-preview-section-title" dangerouslySetInnerHTML={{ __html: sec.pb.label }} />
                        {sec.pb.settings?.description && <p className="ai-preview-section-desc">{stripHtml(sec.pb.settings.description)}</p>}
                      </div>
                    )}
                    {sec.questions.map((q, qIdx) => (
                      <div key={qIdx} className="ai-preview-q">
                        <div className="ai-preview-q-header">
                          <span className="ai-preview-q-num">{qIdx + 1}.</span>
                          <span className="ai-preview-q-label" dangerouslySetInnerHTML={{ __html: q.label }} />
                          {q.is_required && <span className="ai-preview-required" title="Wajib diisi">*</span>}
                          <span className="ai-preview-q-type">{QUESTION_TYPE_LABELS[q.type] || q.type}</span>
                        </div>
                        {q.options && q.options.length > 0 && (
                          <div className="ai-preview-opts">
                            {q.options.map((o, oIdx) => (
                              <div key={oIdx} className={`ai-preview-opt ${o.is_correct ? 'correct' : ''}`}>
                                <span className="ai-preview-opt-dot">{String.fromCharCode(65 + oIdx)}</span>
                                <span dangerouslySetInnerHTML={{ __html: o.label }} />
                                {o.is_correct && (
                                  <span className="ai-preview-correct">
                                    <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}><polyline points="20 6 9 17 4 12" /></svg>
                                    Kunci Jawaban
                                  </span>
                                )}
                              </div>
                            ))}
                          </div>
                        )}
                        {q.type === 'text' && <div className="ai-preview-placeholder">Jawaban teks singkat...</div>}
                        {q.type === 'paragraph' && <div className="ai-preview-placeholder">Jawaban paragraf panjang...</div>}
                        {q.type === 'date' && (
                          <div className="ai-preview-placeholder ai-date-placeholder">
                            <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><rect x="3" y="4" width="18" height="18" rx="2" ry="2" /><line x1="16" y1="2" x2="16" y2="6" /><line x1="8" y1="2" x2="8" y2="6" /><line x1="3" y1="10" x2="21" y2="10" /></svg>
                            Pilih tanggal
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                ))}

                <div className="ai-preview-actions">
                  <button className="ai-btn-secondary" onClick={handleRegenerate} disabled={isGenerating}>
                    <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
                    Regenerate AI
                  </button>
                  <button className="ai-btn-primary" onClick={handleConfirm} disabled={isGenerating}>
                    <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.2}><path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" /></svg>
                    Confirm &amp; Buka Editor Form
                  </button>
                </div>
                <p className="ai-confirm-hint">Setelah Confirm, form otomatis tersimpan sebagai draft dan langsung dapat Anda kelola di editor.</p>
              </div>
            )}
          </section>
        </div>
      </main>

      {toast && <div className={`ai-toast ${toast.type}`}>{toast.msg}</div>}
    </div>
  );
}
