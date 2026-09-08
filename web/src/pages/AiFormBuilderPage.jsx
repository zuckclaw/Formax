import { useState, useCallback, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { createForm } from '../api/forms';
import { generateAiForm } from '../api/ai';
import { getValidToken } from '../utils/authStorage';
import { prepareMathHtml } from '../utils/mathRender';
import ThemeToggle from '../components/ThemeToggle';
import logoForm4x from '../assets/logo_form4x.png';
import '../styles/ai-builder.css';

const DYNAMIC_SUBTITLES = [
  'Buat kuis, survei & form otomatis berstandar tinggi dengan kecerdasan buatan kami!',
  'Susun soal matematika lengkap dengan rumus LaTeX instan & akurat',
  'Generate form pendaftaran & kuesioner interaktif dalam hitungan detik',
  'Solusi kecerdasan buatan terbaik untuk pembuatan formulir modern tanpa ribet',
];

const QUESTION_TYPE_LABELS = {
  text: 'Teks Singkat',
  paragraph: 'Paragraf',
  single_choice: 'Pilihan Ganda',
  checkbox: 'Checkbox',
  dropdown: 'Dropdown',
  date: 'Tanggal',
  file_upload: 'Upload File',
  page_break: 'Bagian Header',
};

const PRESET_PROMPTS = [
  {
    icon: '📐',
    label: 'Ujian Matematika SMA',
    title: 'Kuis Matematika SMA — Aljabar Kuadrat',
    description: 'Ujian pengukur pemahaman aljabar dan fungsi kuadrat kelas 10.',
    prompt: 'Buatkan kuis Matematika SMA kelas 10, 2 Bagian: Identitas Siswa & 5 soal pilihan ganda tentang aljabar kuadrat dan persamaan linear. Sertakan rumus matematika LaTeX \\(f(x) = ax^2 + bx + c\\) dan kunci jawaban akurat.',
    questions: 5,
    includeCorrect: true,
    useSections: true,
  },
  {
    icon: '📊',
    label: 'Survei Kepuasan Pelanggan',
    title: 'Survei Kepuasan & Feedback Pelanggan',
    description: 'Kuesioner evaluasi kualitas layanan, rasa produk, dan keramahan staf.',
    prompt: 'Buatkan kuesioner survei kepuasan pelanggan restoran 5 soal pilihan ganda skala Likert (Sangat Puas s/d Sangat Tidak Puas) dan 1 soal paragraf untuk kritik & saran masukan.',
    questions: 6,
    includeCorrect: false,
    useSections: true,
  },
  {
    icon: '🎓',
    label: 'Form Pendaftaran Event',
    title: 'Form Pendaftaran Webinar Nasional 2026',
    description: 'Pendaftaran peserta webinar teknologi dan kecerdasan buatan.',
    prompt: 'Buatkan formulir pendaftaran webinar 5 bidang: Nama Lengkap (text), Email (text), Instansi/Profesi (dropdown), Tanggal Lahir (date), dan Upload Bukti Transfer/Kartu Identitas (file_upload).',
    questions: 5,
    includeCorrect: false,
    useSections: true,
  },
  {
    icon: '💼',
    label: 'Evaluasi Kinerja Dosen',
    title: 'Survei Evaluasi Pembelajaran & Pengajar',
    description: 'Evaluasi rutin semesteran mengenai metode pengajaran dan kesiapan materi.',
    prompt: 'Buatkan kuesioner evaluasi dosen oleh mahasiswa 5 soal pilihan skala rating (Sangat Baik s/d Sangat Kurang) mengenai penguasaan materi, ketepatan waktu, dan kejelasan penjelasan.',
    questions: 5,
    includeCorrect: false,
    useSections: true,
  },
  {
    icon: '🇬🇧',
    label: 'Kuis Bahasa Inggris',
    title: 'English Proficiency Quiz — Grammar & Tenses',
    description: 'Short quiz to assess basic English grammar, tenses, and daily vocabulary.',
    prompt: 'Make an English exam for 10th grade students focusing on tenses (simple present, past tense, future tense) with 5 multiple choice questions and answer keys.',
    questions: 5,
    includeCorrect: true,
    useSections: true,
  },
];

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
  const [numQuestions, setNumQuestions] = useState(5);
  const [includeCorrect, setIncludeCorrect] = useState(true);
  const [useSections, setUseSections] = useState(true);
  const [isGenerating, setIsGenerating] = useState(false);
  const [preview, setPreview] = useState(null);
  const [error, setError] = useState('');
  const [toast, setToast] = useState(null);
  const [activePreset, setActivePreset] = useState(null);

  // Dynamic Subtitle Cycling Animation State
  const [subtitleIndex, setSubtitleIndex] = useState(0);
  const [isSubtitleFading, setIsSubtitleFading] = useState(false);

  useEffect(() => {
    const timer = setInterval(() => {
      setIsSubtitleFading(true);
      setTimeout(() => {
        setSubtitleIndex((prev) => (prev + 1) % DYNAMIC_SUBTITLES.length);
        setIsSubtitleFading(false);
      }, 400);
    }, 3800);
    return () => clearInterval(timer);
  }, []);

  const showToast = useCallback((msg, type = 'info') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  }, []);

  const handleApplyPreset = (preset, index) => {
    setTitle(preset.title);
    setDescription(preset.description);
    setPrompt(preset.prompt);
    setNumQuestions(preset.questions);
    setIncludeCorrect(preset.includeCorrect);
    setUseSections(preset.useSections);
    setActivePreset(index);
    setError('');
    showToast(`Template "${preset.label}" berhasil diterapkan!`, 'info');
  };

  const handleGenerate = async () => {
    if (!prompt.trim() || prompt.trim().length < 10) {
      setError('Prompt minimal 10 karakter. Jelaskan form yang ingin Anda buat.');
      return;
    }
    if (numQuestions < 3 || numQuestions > 30) {
      setError('Jumlah soal harus antara 3 hingga 30.');
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
      showToast('Form cerdas berhasil digenerate!', 'success');
    } catch (err) {
      setError(err.message || 'Gagal generate form');
      showToast(err.message || 'Gagal generate form', 'error');
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
        title: preview.title || title || 'Form Buatan Formax AI',
        description: preview.description || description || '',
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
      };
      
      const created = await createForm(token, {
        title: payload.title,
        description: payload.description,
        slug: `ai-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 6)}`,
        questions: payload.questions,
        status: 'draft',
        allow_see_result: false,
        max_submissions: 0,
        require_fullscreen: false,
        reveal_answers: includeCorrect,
      });
      showToast('Form disimpan! Mengalihkan ke editor...', 'success');
      setTimeout(() => navigate(`/form-builder/${created.id}`), 700);
    } catch (err) {
      showToast(err.message || 'Gagal menyimpan form', 'error');
    } finally {
      setIsGenerating(false);
    }
  };

  const handleBack = () => navigate('/dashboard');

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
      {/* Animated Ambient Waves Background */}
      <div className="ai-bg-waves" aria-hidden="true">
        <div className="ai-glow-orb orb-1" />
        <div className="ai-glow-orb orb-2" />
        <div className="ai-glow-orb orb-3" />
        <svg className="ai-wave-svg wave-1" viewBox="0 0 1440 320" preserveAspectRatio="none">
          <path fill="currentColor" d="M0,192L48,176C96,160,192,128,288,138.7C384,149,480,203,576,213.3C672,224,768,192,864,165.3C960,139,1056,117,1152,128C1248,139,1344,181,1392,202.7L1440,224L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z" />
        </svg>
        <svg className="ai-wave-svg wave-2" viewBox="0 0 1440 320" preserveAspectRatio="none">
          <path fill="currentColor" d="M0,96L48,122.7C96,149,192,203,288,208C384,213,480,171,576,144C672,117,768,107,864,128C960,149,1056,203,1152,213.3C1248,224,1344,160,1392,128L1440,96L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z" />
        </svg>
        <svg className="ai-wave-svg wave-3" viewBox="0 0 1440 320" preserveAspectRatio="none">
          <path fill="currentColor" d="M0,224L60,213.3C120,203,240,181,360,186.7C480,192,600,224,720,213.3C840,203,960,149,1080,138.7C1200,128,1320,160,1380,176L1440,192L1440,320L1380,320C1320,320,1200,320,1080,320C960,320,840,320,720,320C600,320,480,320,360,320C240,320,120,320,60,320L0,320Z" />
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
              <span className="ai-badge-chip">Smart Engine 2.0</span>
            </div>
            <p className={`ai-subtitle ${isSubtitleFading ? 'fading' : ''}`}>
              {DYNAMIC_SUBTITLES[subtitleIndex]}
            </p>
          </div>
        </div>
        <div className="ai-header-right">
          <ThemeToggle />
        </div>
      </header>

      <main className="ai-main">
        <div className="ai-grid">
          {/* LEFT: Input & Primary Prompt Action */}
          <section className="ai-card ai-input-card">
            <div className="ai-card-header">
              <div className="ai-card-icon-wrap">
                <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456z" />
                </svg>
              </div>
              <div>
                <h2 className="ai-card-title">Instruksi AI (Prompt)</h2>
                <p className="ai-card-desc">Tulis instruksi atau pilih template cepat untuk membuat form cerdas secara otomatis.</p>
              </div>
            </div>

            {/* PRESET PROMPT CHIPS */}
            <div className="ai-presets-container">
              <span className="ai-presets-label">⚡ Template Prompt Cepat:</span>
              <div className="ai-presets-grid">
                {PRESET_PROMPTS.map((preset, idx) => (
                  <button
                    key={idx}
                    type="button"
                    className={`ai-preset-chip ${activePreset === idx ? 'active' : ''}`}
                    onClick={() => handleApplyPreset(preset, idx)}
                  >
                    <span className="ai-preset-icon">{preset.icon}</span>
                    <span>{preset.label}</span>
                  </button>
                ))}
              </div>
            </div>

            <div className="ai-form-group">
              <label className="ai-label">Judul Form <span className="ai-optional">(opsional)</span></label>
              <input className="ai-input" type="text" placeholder="Contoh: Kuis Matematika SMA — Aljabar" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={120} />
            </div>

            <div className="ai-form-group">
              <label className="ai-label">Deskripsi Form <span className="ai-optional">(opsional)</span></label>
              <textarea className="ai-textarea" rows={2} placeholder="Contoh: Petunjuk pengerjaan dan durasi waktu..." value={description} onChange={(e) => setDescription(e.target.value)} maxLength={2000} />
            </div>

            <div className="ai-form-group">
              <label className="ai-label">Instruksi Detail Prompt <span className="ai-required">*</span></label>
              <textarea
                className="ai-textarea ai-prompt"
                rows={5}
                placeholder="Contoh: Buatkan ujian Matematika SMA kelas 10 tentang fungsi kuadrat, 5 soal pilihan ganda dengan 4 opsi, kunci jawaban akurat, dan rumus LaTeX \(f(x) = ax^2 + bx + c\)..."
                value={prompt}
                onChange={(e) => {
                  setPrompt(e.target.value);
                  setActivePreset(null);
                }}
                maxLength={4000}
              />
              <div className="ai-char-count">{prompt.length} / 4000 karakter</div>
            </div>

            {error && (
              <div className="ai-error">
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
                <span>{error}</span>
              </div>
            )}

            {/* GENERATE BUTTON DIRECTLY UNDER PROMPT */}
            <button className="ai-generate-btn" onClick={handleGenerate} disabled={isGenerating || !prompt.trim()}>
              {isGenerating ? (
                <>
                  <span className="ai-btn-spinner" />
                  Formax AI Sedang Meracik...
                </>
              ) : (
                <>
                  <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.2}><path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" /></svg>
                  Generate Form Cerdas
                </>
              )}
            </button>
            <p className="ai-generate-hint">Otomatis mendeteksi Bahasa Indonesia &amp; Inggris secara mulus</p>
          </section>

          {/* RIGHT PANEL: Live Preview + Dedicated Settings UI */}
          <div className="ai-right-panel">
            {/* CARD 1: Live Preview */}
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
                    <p className="ai-card-desc">Review struktur form sebelum dikonfirmasi dan dimasukkan ke Editor Form.</p>
                  </div>
                </div>
                {preview && (
                  <span className="ai-preview-count">
                    {preview.questions.filter((q) => q.type !== 'page_break').length} Pertanyaan &bull; {previewSections.length} Bagian
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
                    <span>Menganalisis instruksi, menyusun soal &amp; merender formula matematika</span>
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
                  <p>Belum Ada Hasil Form</p>
                  <small>Pilih salah satu <strong>Template Prompt Cepat</strong> atau ketik instruksi di sebelah kiri, lalu klik <strong>Generate Form Cerdas</strong>.</small>
                </div>
              )}

              {!isGenerating && preview && (
                <div className="ai-preview-content">
                  <div className="ai-preview-form-header">
                    <h3 className="ai-preview-title" dangerouslySetInnerHTML={{ __html: prepareMathHtml(preview.title) }} />
                    {preview.description && <p className="ai-preview-desc" dangerouslySetInnerHTML={{ __html: prepareMathHtml(preview.description) }} />}
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
                          <h4 className="ai-preview-section-title" dangerouslySetInnerHTML={{ __html: prepareMathHtml(sec.pb.label) }} />
                          {sec.pb.settings?.description && <p className="ai-preview-section-desc">{stripHtml(sec.pb.settings.description)}</p>}
                        </div>
                      )}
                      {sec.questions.map((q, qIdx) => (
                        <div key={qIdx} className="ai-preview-q">
                          <div className="ai-preview-q-header">
                            <span className="ai-preview-q-num">{qIdx + 1}.</span>
                            <span className="ai-preview-q-label" dangerouslySetInnerHTML={{ __html: prepareMathHtml(q.label) }} />
                            {q.is_required && <span className="ai-preview-required" title="Wajib diisi">*</span>}
                            <span className="ai-preview-q-type">{QUESTION_TYPE_LABELS[q.type] || q.type}</span>
                          </div>
                          {q.options && q.options.length > 0 && (
                            <div className="ai-preview-opts">
                              {q.options.map((o, oIdx) => (
                                <div key={oIdx} className={`ai-preview-opt ${o.is_correct ? 'correct' : ''}`}>
                                  <span className="ai-preview-opt-dot">{String.fromCharCode(65 + oIdx)}</span>
                                  <span dangerouslySetInnerHTML={{ __html: prepareMathHtml(o.label) }} />
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
                          {q.type === 'text' && <div className="ai-preview-placeholder">{q.placeholder || 'Jawaban teks singkat...'}</div>}
                          {q.type === 'paragraph' && <div className="ai-preview-placeholder">{q.placeholder || 'Jawaban paragraf panjang...'}</div>}
                          {q.type === 'date' && (
                            <div className="ai-preview-placeholder ai-date-placeholder">
                              <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><rect x="3" y="4" width="18" height="18" rx="2" ry="2" /><line x1="16" y1="2" x2="16" y2="6" /><line x1="8" y1="2" x2="8" y2="6" /><line x1="3" y1="10" x2="21" y2="10" /></svg>
                              Pilih Tanggal
                            </div>
                          )}
                          {q.type === 'file_upload' && (
                            <div className="ai-preview-placeholder ai-date-placeholder">
                              <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" /></svg>
                              Pilih berkas dokumen/gambar untuk diunggah...
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
                  <p className="ai-confirm-hint">Setelah Confirm, form otomatis tersimpan sebagai draft dan langsung dapat Anda kelola di Editor Formax.</p>
                </div>
              )}
            </section>

            {/* CARD 2: Pengaturan Detail Form & Opsi AI */}
            <section className="ai-card ai-settings-card">
              <div className="ai-card-header">
                <div className="ai-card-icon-wrap settings-icon">
                  <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                    <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                </div>
                <div>
                  <h2 className="ai-card-title">Pengaturan Form &amp; Opsi AI</h2>
                  <p className="ai-card-desc">Atur jumlah target soal, kunci jawaban otomatis, dan struktur bagian form.</p>
                </div>
              </div>

              <div className="ai-form-group">
                <label className="ai-label">Target Jumlah Soal / Pertanyaan</label>
                <div className="ai-num-row">
                  <input type="range" min={3} max={30} value={numQuestions} onChange={(e) => setNumQuestions(Number(e.target.value))} className="ai-range" />
                  <div className="ai-num-badge">{numQuestions} Soal</div>
                </div>
                <span className="ai-hint">Kisaran 3-30 soal (rekomendasi: 5-10)</span>
              </div>

              <div className="ai-toggles">
                <label className="ai-toggle-row">
                  <div className="ai-toggle-info">
                    <span className="ai-toggle-title">Kunci Jawaban Otomatis</span>
                    <span className="ai-toggle-sub">AI menandai 1 opsi benar untuk tiap soal pilihan ganda</span>
                  </div>
                  <button type="button" className={`ai-toggle ${includeCorrect ? 'on' : 'off'}`} onClick={() => setIncludeCorrect((v) => !v)} aria-label="Toggle kunci jawaban">
                    <span className="ai-toggle-slider" />
                  </button>
                </label>

                <label className="ai-toggle-row">
                  <div className="ai-toggle-info">
                    <span className="ai-toggle-title">Gunakan Bagian (Section)</span>
                    <span className="ai-toggle-sub">Pisahkan Bagian Identitas &amp; Bagian Pertanyaan</span>
                  </div>
                  <button type="button" className={`ai-toggle ${useSections ? 'on' : 'off'}`} onClick={() => setUseSections((v) => !v)} aria-label="Toggle bagian">
                    <span className="ai-toggle-slider" />
                  </button>
                </label>
              </div>

              <div className="ai-billing-hint" style={{ marginTop: '20px' }}>
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
                </svg>
                <span>Model AI: <strong>Formax Smart Architect</strong> — Berkualitas Tinggi &amp; mendukung LaTeX.</span>
              </div>
            </section>
          </div>
        </div>
      </main>

      {toast && <div className={`ai-toast ${toast.type}`}>{toast.msg}</div>}
    </div>
  );
}
