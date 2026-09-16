import { useState, useCallback, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { createForm } from '../api/forms';
import { generateAiForm, extractAiFileText } from '../api/ai';
import { getValidToken } from '../utils/authStorage';
import { prepareMathHtml } from '../utils/mathRender';
import { safeHtml } from '../utils/safeHtml';
import { validatePrompt, extractQuestionCountFromPrompt } from '../utils/promptValidator';
import AiIntroPortal from '../components/AiIntroPortal';
import ThemeToggle from '../components/ThemeToggle';
import 'katex/dist/katex.min.css';
import logoForm4x from '../assets/logo_form4x.png';
import '../styles/ai-builder.css';

const GUIDE_STEPS = [
  {
    icon: '1',
    title: 'Tulis Instruksi',
    desc: 'Ketikkan deskripsi form yang Anda inginkan di kotak input. Contoh: "Buatkan kuis Matematika SMA 5 soal pilihan ganda tentang aljabar."',
  },
  {
    icon: '2',
    title: 'Pilih Template (Opsional)',
    desc: 'Klik salah satu template bubble di atas kotak input untuk mengisi instruksi secara otomatis.',
  },
  {
    icon: '3',
    title: 'Atur Opsi',
    desc: 'Tentukan jumlah soal, aktifkan kunci jawaban, atau bagi ke dalam sesi menggunakan toolbar di bawah kotak input.',
  },
  {
    icon: '4',
    title: 'Sisipkan Dokumen (Opsional)',
    desc: 'Lampirkan file .docx, .txt, atau .csv agar AI membaca isi dokumen sebagai konteks tambahan.',
  },
  {
    icon: '5',
    title: 'Generate & Simpan',
    desc: 'Klik "Buat Form" atau tekan Ctrl+Enter. Review hasilnya, lalu klik "Simpan & Buka di Editor" untuk mulai mengedit.',
  },
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
    description: 'Ujian pemahaman aljabar kuadrat dan persamaan linear kelas 10.',
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
    label: 'Pendaftaran Webinar',
    title: 'Form Pendaftaran Webinar Nasional 2026',
    description: 'Pendaftaran peserta webinar teknologi dan kecerdasan buatan.',
    prompt: 'Buatkan formulir pendaftaran webinar 5 bidang: Nama Lengkap (text), Email (text), Instansi/Profesi (dropdown), Tanggal Lahir (date), dan Upload Bukti Transfer/Kartu Identitas (file_upload).',
    questions: 5,
    includeCorrect: false,
    useSections: true,
  },
  {
    icon: '💼',
    label: 'Evaluasi Pembelajaran',
    title: 'Survei Evaluasi Pembelajaran & Pengajar',
    description: 'Evaluasi rutin semesteran mengenai metode pengajaran dan kesiapan materi.',
    prompt: 'Buatkan kuesioner evaluasi dosen oleh mahasiswa 5 soal pilihan skala rating (Sangat Baik s/d Sangat Kurang) mengenai penguasaan materi, ketepatan waktu, dan kejelasan penjelasan.',
    questions: 5,
    includeCorrect: false,
    useSections: true,
  },
  {
    icon: '🇬🇧',
    label: 'English Quiz',
    title: 'English Proficiency Quiz — Grammar & Tenses',
    description: 'Quiz to assess basic English grammar, tenses, and daily vocabulary.',
    prompt: 'Make an English exam for 10th grade students focusing on tenses (simple present, past tense, future tense) with 5 multiple choice questions and answer keys.',
    questions: 5,
    includeCorrect: true,
    useSections: true,
  },
];

export default function AiFormBuilderPage() {
  const navigate = useNavigate();
  const token = getValidToken();
  const fileInputRef = useRef(null);
  const textareaRef = useRef(null);

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
  const [showPortal, setShowPortal] = useState(true);
  const [showTitleField, setShowTitleField] = useState(false);
  const [showGuide, setShowGuide] = useState(false);
  const guideRef = useRef(null);

  // File Attachment State
  const [attachedFile, setAttachedFile] = useState(null); // { name, size, text, charCount }
  const [isExtractingFile, setIsExtractingFile] = useState(false);

  // Auto-resize prompt textarea
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = `${Math.min(260, Math.max(80, textareaRef.current.scrollHeight))}px`;
    }
  }, [prompt]);

  useEffect(() => {
    if (!showGuide) return;
    const handleClickOutside = (e) => {
      if (guideRef.current && !guideRef.current.contains(e.target)) {
        setShowGuide(false);
      }
    };
    const handleEsc = (e) => {
      if (e.key === 'Escape') setShowGuide(false);
    };
    document.addEventListener('mousedown', handleClickOutside);
    document.addEventListener('keydown', handleEsc);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('keydown', handleEsc);
    };
  }, [showGuide]);

  const showToast = useCallback((msg, type = 'info') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3200);
  }, []);

  const handleApplyPreset = (preset) => {
    setTitle(preset.title);
    setDescription(preset.description);
    setPrompt(preset.prompt);
    setNumQuestions(preset.questions);
    setIncludeCorrect(preset.includeCorrect);
    setUseSections(preset.useSections);
    setError('');
    showToast(`Template "${preset.label}" diterapkan!`, 'info');
    if (textareaRef.current) {
      textareaRef.current.focus();
    }
  };

  const handleFileUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > 8 * 1024 * 1024) {
      showToast('Ukuran file maksimal 8 MB', 'error');
      return;
    }

    const filename = file.name.toLowerCase();
    const validExtensions = ['.docx', '.txt', '.md', '.csv', '.json', '.tsv'];
    const isValid = validExtensions.some((ext) => filename.endsWith(ext));
    if (!isValid) {
      showToast('Format tidak didukung. Gunakan .docx, .txt, .md, .csv, atau .json', 'error');
      return;
    }

    setIsExtractingFile(true);
    try {
      // If it's pure text / md / json / csv, read instantly via FileReader
      if (!filename.endsWith('.docx')) {
        const reader = new FileReader();
        reader.onload = (event) => {
          const content = event.target.result || '';
          setAttachedFile({
            name: file.name,
            size: (file.size / 1024).toFixed(1) + ' KB',
            text: content.slice(0, 15000),
            charCount: content.length,
          });
          setIsExtractingFile(false);
          showToast(`File "${file.name}" siap digunakan oleh AI!`, 'success');
        };
        reader.onerror = () => {
          setIsExtractingFile(false);
          showToast('Gagal membaca file teks', 'error');
        };
        reader.readAsText(file);
      } else {
        // Extract .docx on server
        const res = await extractAiFileText(token, file);
        setAttachedFile({
          name: file.name,
          size: (file.size / 1024).toFixed(1) + ' KB',
          text: res.text,
          charCount: res.char_count,
        });
        showToast(`Dokumen Word "${file.name}" berhasil diekstraksi!`, 'success');
        setIsExtractingFile(false);
      }
    } catch (err) {
      setIsExtractingFile(false);
      showToast(err.message || 'Gagal mengekstrak isi file', 'error');
    } finally {
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const handleRemoveFile = () => {
    setAttachedFile(null);
    showToast('File lampiran dilepas', 'info');
  };

  const handleGenerate = async () => {
    const validation = validatePrompt(prompt);
    if (!validation.isValid) {
      setError(validation.error);
      showToast(validation.error, 'error');
      return;
    }

    const detectedCount = extractQuestionCountFromPrompt(prompt);
    const resolvedNumQuestions = detectedCount !== null ? detectedCount : numQuestions;

    if (resolvedNumQuestions < 3 || resolvedNumQuestions > 30) {
      setError('Jumlah soal harus antara 3 hingga 30.');
      return;
    }
    if (detectedCount !== null && detectedCount !== numQuestions) {
      setNumQuestions(detectedCount);
    }

    setError('');
    setIsGenerating(true);
    try {
      const data = await generateAiForm(token, {
        title: title.trim() || undefined,
        description: description.trim() || undefined,
        prompt: prompt.trim(),
        num_questions: Number(resolvedNumQuestions),
        include_correct: includeCorrect,
        use_sections: useSections,
        file_context: attachedFile?.text || undefined,
      });
      setPreview(data);
      showToast('Form berhasil diracik oleh Formax AI!', 'success');
    } catch (err) {
      setError(err.message || 'Gagal generate form');
      showToast(err.message || 'Gagal generate form', 'error');
    } finally {
      setIsGenerating(false);
    }
  };

  const handleKeyDown = (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
      e.preventDefault();
      if (!isGenerating && prompt.trim()) {
        handleGenerate();
      }
    }
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
      setTimeout(() => navigate(`/form-builder/${created.id}`), 600);
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
    <div className={`claude-ai-root ${!showPortal ? 'ai-stagger-in' : ''}`}>
      {showPortal && <AiIntroPortal onComplete={() => setShowPortal(false)} />}

      {/* Signature Soft Wave Background */}
      <div className="claude-wave-bg" aria-hidden="true">
        <div className="claude-wave-orb claude-wave-orb-a" />
        <div className="claude-wave-orb claude-wave-orb-b" />
        <svg className="claude-wave-svg" viewBox="0 0 1440 320" preserveAspectRatio="none">
          <path className="claude-wave-path wave-back" d="M0,160L48,149.3C96,139,192,117,288,128C384,139,480,181,576,186.7C672,192,768,160,864,138.7C960,117,1056,107,1152,122.7C1248,139,1344,181,1392,202.7L1440,224L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z" />
          <path className="claude-wave-path wave-front" d="M0,224L60,213.3C120,203,240,181,360,186.7C480,192,600,224,720,213.3C840,203,960,160,1080,149.3C1200,139,1320,160,1380,170.7L1440,181L1440,320L1380,320C1320,320,1200,320,1080,320C960,320,840,320,720,320C600,320,480,320,360,320C240,320,120,320,60,320L0,320Z" />
        </svg>
      </div>

      {/* Modern Clean Top Navbar */}
      <header className="claude-ai-nav">
        <div className="claude-ai-nav-left">
          <button className="claude-back-btn" onClick={handleBack} title="Kembali ke Dasbor">
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            <span>Dasbor</span>
          </button>
          <div className="claude-brand-divider" />
          <div className="claude-brand">
            <img src={logoForm4x} alt="Form4x" className="claude-logo-img" />
            <span className="claude-brand-name">Formax AI</span>
            <span className="claude-badge">Smart Architect</span>
          </div>
        </div>
        <div className="claude-ai-nav-right">
          {preview && (
            <button
              className="claude-btn-new-prompt"
              onClick={() => {
                setPreview(null);
                setPrompt('');
                setAttachedFile(null);
              }}
            >
              <svg width="15" height="15" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
              </svg>
              <span>Buat Baru</span>
            </button>
          )}
          <div className="claude-guide-wrapper" ref={guideRef}>
            <button
              className={`claude-guide-btn ${showGuide ? 'active' : ''}`}
              onClick={() => setShowGuide((v) => !v)}
              title="Petunjuk Penggunaan"
              aria-label="Petunjuk Penggunaan"
            >
              <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </button>
            {showGuide && (
              <div className="claude-guide-panel">
                <div className="claude-guide-panel-header">
                  <h3 className="claude-guide-panel-title">Cara Menggunakan Formax AI</h3>
                  <button className="claude-guide-panel-close" onClick={() => setShowGuide(false)} aria-label="Tutup">
                    <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
                <ol className="claude-guide-steps">
                  {GUIDE_STEPS.map((step, i) => (
                    <li key={i} className="claude-guide-step">
                      <span className="claude-guide-step-num">{step.icon}</span>
                      <div className="claude-guide-step-body">
                        <strong className="claude-guide-step-title">{step.title}</strong>
                        <p className="claude-guide-step-desc">{step.desc}</p>
                      </div>
                    </li>
                  ))}
                </ol>
              </div>
            )}
          </div>
          <ThemeToggle />
        </div>
      </header>

      {/* Main Content Area */}
      <main className="claude-main-container">
        {/* Toast Notification */}
        {toast && (
          <div className={`claude-toast claude-toast-${toast.type}`}>
            <span>{toast.msg}</span>
          </div>
        )}

        {!preview ? (
          /* =======================================================================
             VIEW 1: PROMPT WORKSPACE (Claude Central Omnibox)
             ======================================================================= */
          <div className="claude-hero-section">
            <div className="claude-hero-header">
              <h1 className="claude-hero-title">Formulir apa yang ingin Anda buat hari ini?</h1>
              <p className="claude-hero-desc">
                Ketik instruksi, pilih templat instan, atau sisipkan dokumen untuk membuat ujian, kuis, atau kuesioner otomatis.
              </p>
            </div>

            <div className="claude-bottom-input-zone">
              {/* PRESET PROMPTS / TEMPLATE BUBBLES DI ATAS KOTAK INPUT */}
              <div className="claude-template-bubbles">
                {PRESET_PROMPTS.map((preset, idx) => (
                  <button
                    key={idx}
                    type="button"
                    className="claude-template-bubble"
                    onClick={() => handleApplyPreset(preset)}
                    title={preset.title}
                  >
                    <span className="claude-bubble-icon">{preset.icon}</span>
                    <span className="claude-bubble-label">{preset.label}</span>
                  </button>
                ))}
              </div>

              {/* THE CLAUDE OMNIBOX */}
              <div className={`claude-omnibox-card ${error ? 'has-error' : ''}`}>
              {/* Optional Form Title & Description Expander */}
              {showTitleField && (
                <div className="claude-custom-meta">
                  <input
                    type="text"
                    className="claude-meta-input"
                    placeholder="Judul Form (opsional)..."
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    maxLength={120}
                  />
                  <input
                    type="text"
                    className="claude-meta-input meta-desc"
                    placeholder="Deskripsi / Petunjuk Singkat (opsional)..."
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    maxLength={500}
                  />
                </div>
              )}

              {/* Main Prompt Textarea */}
              <textarea
                ref={textareaRef}
                className="claude-omnibox-textarea"
                rows={3}
                placeholder="Deskripsikan form yang Anda butuhkan (contoh: 'Buatkan kuis Matematika SMA 5 soal tentang fungsi kuadrat dengan rumus LaTeX dan kunci jawaban')..."
                value={prompt}
                onChange={(e) => {
                  const val = e.target.value;
                  setPrompt(val);
                  if (error) setError('');
                  const detected = extractQuestionCountFromPrompt(val);
                  if (detected !== null && detected !== numQuestions) {
                    setNumQuestions(detected);
                  }
                }}
                onKeyDown={handleKeyDown}
                maxLength={4000}
              />

              {/* Attached File Preview Chip */}
              {attachedFile && (
                <div className="claude-attached-chip">
                  <div className="claude-attached-icon">📄</div>
                  <div className="claude-attached-info">
                    <span className="claude-attached-name">{attachedFile.name}</span>
                    <span className="claude-attached-meta">
                      {attachedFile.size} &bull; {attachedFile.charCount.toLocaleString()} karakter terbaca
                    </span>
                  </div>
                  <button
                    type="button"
                    className="claude-attached-remove"
                    onClick={handleRemoveFile}
                    title="Hapus file lampiran"
                  >
                    <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              )}

              {/* Error Message */}
              {error && (
                <div className="claude-omnibox-error">
                  <svg width="15" height="15" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                  <span>{error}</span>
                </div>
              )}

              {/* Omnibox Bottom Toolbar */}
              <div className="claude-omnibox-toolbar">
                <div className="claude-toolbar-left">
                  {/* Hidden File Input */}
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept=".docx,.txt,.md,.csv,.json,.tsv"
                    style={{ display: 'none' }}
                    onChange={handleFileUpload}
                  />

                  {/* Attachment Button */}
                  <button
                    type="button"
                    className={`claude-toolbar-btn ${attachedFile ? 'active' : ''}`}
                    onClick={() => fileInputRef.current?.click()}
                    disabled={isExtractingFile}
                    title="Sisipkan file dokumen (.docx, .txt, .md, .csv, .json)"
                  >
                    {isExtractingFile ? (
                      <span className="claude-micro-spinner" />
                    ) : (
                      <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
                      </svg>
                    )}
                    <span>{attachedFile ? 'File Terlampir' : 'Sisipkan File'}</span>
                  </button>

                  {/* Question Count Pill Dropdown */}
                  <div className="claude-pill-dropdown-wrap">
                    <select
                      className="claude-pill-select"
                      value={numQuestions}
                      onChange={(e) => setNumQuestions(Number(e.target.value))}
                      title="Jumlah target soal"
                    >
                      {[3, 4, 5, 6, 7, 8, 10, 12, 15, 20, 25, 30].map((n) => (
                        <option key={n} value={n}>
                          {n} Soal
                        </option>
                      ))}
                    </select>
                  </div>

                  {/* Correct Answers Toggle Pill */}
                  <button
                    type="button"
                    className={`claude-pill-toggle ${includeCorrect ? 'active' : ''}`}
                    onClick={() => setIncludeCorrect((v) => !v)}
                    title="Aktifkan/Matikan kunci jawaban otomatis untuk pilihan ganda"
                  >
                    <span className="claude-pill-dot" />
                    <span>Kunci Jawaban</span>
                  </button>

                  {/* Sections Toggle Pill */}
                  <button
                    type="button"
                    className={`claude-pill-toggle ${useSections ? 'active' : ''}`}
                    onClick={() => setUseSections((v) => !v)}
                    title="Bagi formulir ke dalam beberapa sesi (Identitas & Soal)"
                  >
                    <span className="claude-pill-dot" />
                    <span>Bagian Sesi</span>
                  </button>

                  {/* Toggle Custom Title Button */}
                  <button
                    type="button"
                    className={`claude-toolbar-btn-text ${showTitleField ? 'active' : ''}`}
                    onClick={() => setShowTitleField((v) => !v)}
                  >
                    {showTitleField ? 'Tutup Judul Kustom' : '+ Judul Kustom'}
                  </button>
                </div>

                <div className="claude-toolbar-right">
                  <span className="claude-char-hint">{prompt.length} / 4000</span>
                  <button
                    type="button"
                    className="claude-send-btn"
                    onClick={handleGenerate}
                    disabled={isGenerating || !prompt.trim()}
                    title="Generate Form (Ctrl + Enter)"
                  >
                    {isGenerating ? (
                      <span className="claude-send-spinner" />
                    ) : (
                      <svg width="17" height="17" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.4}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M5 12h14M12 5l7 7-7 7" />
                      </svg>
                    )}
                    <span>{isGenerating ? 'Meracik...' : 'Buat Form'}</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
        ) : (
          /* =======================================================================
             VIEW 2: GENERATED RESULT WORKSPACE (Artifacts View)
             ======================================================================= */
          <div className="claude-result-layout">
            {/* Left Column: Quick Tweak Bar */}
            <aside className="claude-result-sidebar">
              <div className="claude-sidebar-card">
                <h3 className="claude-sidebar-heading">Instruksi AI Digunakan</h3>
                <p className="claude-sidebar-prompt-text">"{prompt}"</p>

                <div className="claude-sidebar-meta-list">
                  <div className="claude-sidebar-meta-item">
                    <span className="meta-label">Total Soal</span>
                    <span className="meta-val">{preview.questions.filter((q) => q.type !== 'page_break').length}</span>
                  </div>
                  <div className="claude-sidebar-meta-item">
                    <span className="meta-label">Bagian (Sesi)</span>
                    <span className="meta-val">{previewSections.length}</span>
                  </div>
                  <div className="claude-sidebar-meta-item">
                    <span className="meta-label">Kunci Jawaban</span>
                    <span className="meta-val">{includeCorrect ? 'Aktif' : 'Non-aktif'}</span>
                  </div>
                </div>

                <div className="claude-sidebar-actions">
                  <button
                    className="claude-btn-outline"
                    onClick={handleGenerate}
                    disabled={isGenerating}
                  >
                    <svg width="15" height="15" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                    </svg>
                    <span>{isGenerating ? 'Meracik Ulang...' : 'Regenerate'}</span>
                  </button>
                  <button
                    className="claude-btn-outline"
                    onClick={() => setPreview(null)}
                  >
                    <span>Edit Prompt</span>
                  </button>
                </div>
              </div>
            </aside>

            {/* Right Column: Live Form Sheet */}
            <section className="claude-result-main">
              <div className="claude-result-action-bar">
                <div>
                  <h2 className="claude-result-top-title">Hasil Racikan Formax AI</h2>
                  <p className="claude-result-top-sub">Review seluruh pertanyaan dan rumus LaTeX sebelum disimpan ke formulir.</p>
                </div>
                <button
                  className="claude-btn-primary-glow"
                  onClick={handleConfirm}
                  disabled={isGenerating}
                >
                  <svg width="17" height="17" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                  </svg>
                  <span>{isGenerating ? 'Menyimpan...' : 'Simpan & Buka di Editor'}</span>
                </button>
              </div>

              {/* Form Artifact Paper */}
              <div className="claude-form-paper">
                <div className="claude-paper-header">
                  <h1
                    className="claude-paper-title"
                    dangerouslySetInnerHTML={{ __html: safeHtml(prepareMathHtml(preview.title)) }}
                  />
                  {preview.description && (
                    <p
                      className="claude-paper-desc"
                      dangerouslySetInnerHTML={{ __html: safeHtml(prepareMathHtml(preview.description)) }}
                    />
                  )}
                </div>

                {previewSections.map((sec, sIdx) => (
                  <div key={sIdx} className="claude-section-block">
                    {sec.pb && (
                      <div className="claude-section-header">
                        <div className="claude-section-top">
                          <span className="claude-section-pill">Bagian {sIdx + 1}</span>
                          {sec.pb.settings?.shuffle && (
                            <span className="claude-shuffle-pill">🔀 Acak Soal</span>
                          )}
                        </div>
                        <h3
                          className="claude-section-title"
                          dangerouslySetInnerHTML={{ __html: safeHtml(prepareMathHtml(sec.pb.label)) }}
                        />
                        {sec.pb.settings?.description && (
                          <p
                            className="claude-section-desc"
                            dangerouslySetInnerHTML={{ __html: safeHtml(prepareMathHtml(sec.pb.settings.description)) }}
                          />
                        )}
                      </div>
                    )}

                    <div className="claude-questions-flow">
                      {sec.questions.map((q, qIdx) => (
                        <div key={qIdx} className="claude-q-card">
                          <div className="claude-q-top">
                            <span className="claude-q-number">{qIdx + 1}</span>
                            <div className="claude-q-label-wrap">
                              <div
                                className="claude-q-label"
                                dangerouslySetInnerHTML={{ __html: safeHtml(prepareMathHtml(q.label)) }}
                              />
                            </div>
                            <span className="claude-q-type-badge">
                              {QUESTION_TYPE_LABELS[q.type] || q.type}
                            </span>
                          </div>

                          {/* Options if choices */}
                          {['single_choice', 'checkbox', 'dropdown'].includes(q.type) && (
                            <div className="claude-q-options">
                              {(q.options || []).map((opt, oIdx) => (
                                <div
                                  key={oIdx}
                                  className={`claude-option-item ${opt.is_correct ? 'is-correct' : ''}`}
                                >
                                  <div className="claude-option-indicator">
                                    {q.type === 'single_choice' && <span className="radio-circle" />}
                                    {q.type === 'checkbox' && <span className="checkbox-square" />}
                                    {q.type === 'dropdown' && <span className="dropdown-num">{oIdx + 1}</span>}
                                  </div>
                                  <span
                                    className="claude-option-label"
                                    dangerouslySetInnerHTML={{ __html: safeHtml(prepareMathHtml(opt.label)) }}
                                  />
                                  {opt.is_correct && (
                                    <span className="claude-correct-badge">✓ Kunci Jawaban</span>
                                  )}
                                </div>
                              ))}
                            </div>
                          )}

                          {q.type === 'text' && (
                            <div className="claude-input-dummy">
                              <span>{q.placeholder || 'Jawaban teks singkat...'}</span>
                            </div>
                          )}

                          {q.type === 'paragraph' && (
                            <div className="claude-input-dummy dummy-long">
                              <span>Jawaban paragraf panjang...</span>
                            </div>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </section>
          </div>
        )}
      </main>
    </div>
  );
}
