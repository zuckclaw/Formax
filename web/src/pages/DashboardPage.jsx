import { useEffect, useState, useRef } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { getMe, logout } from '../api/auth';
import { getMyForms, deleteForm, getForm, getFormSubmissions, exportSubmissions } from '../api/forms';
import { getTemplates, deleteTemplate } from '../api/templates';
import { getMySubmissions, getSubmissionResult } from '../api/submissions';
import { parseServerTime } from '../utils/date';
import logoForm4x from '../assets/logo_form4x.png';
import ThemeToggle from '../components/ThemeToggle';
import NgrokImage from '../components/NgrokImage';
import '../styles/dashboard.css';

// Helper: ubah HTML WYSIWYG (Quill) menjadi teks polos agar tidak bocor tag di riwayat
function stripHtml(html) {
  if (!html) return '';
  // Jika sudah teks polos tanpa tag, langsung kembalikan
  if (!html.includes('<')) return html.trim();
  try {
    const div = document.createElement('div');
    div.innerHTML = html;
    // textContent otomatis hilangkan semua tag <p>, <pre>, <strong>, dll
    // ganti &nbsp; dan rapikan whitespace
    const text = (div.textContent || div.innerText || '')
      .replace(/\u00a0/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    // Fallback jika hasilnya kosong tapi html ada isinya (mis. hanya <p><br></p>)
    return text || html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
  } catch {
    return html.replace(/<[^>]*>/g, ' ').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ').trim();
  }
}

function plainLabel(html, fallback = 'Pertanyaan tanpa judul') {
  const t = stripHtml(html);
  return t || fallback;
}

export default function DashboardPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [activeNav, setActiveNav] = useState('dashboard');
  const [searchQuery, setSearchQuery] = useState('');
  const [templates, setTemplates] = useState([]);
  const [recentForms, setRecentForms] = useState([]);
  const [allForms, setAllForms] = useState([]);
  const [contextMenu, setContextMenu] = useState(null); // { type: 'form'|'template', id }
  const [toast, setToast] = useState(null);
  const contextRef = useRef(null);

  // History / Results Subviews: 'list' | 'results' | 'detail'
  const [historySubView, setHistorySubView] = useState('list');
  const [selectedFormForResults, setSelectedFormForResults] = useState(null);
  const [formDetail, setFormDetail] = useState(null);
  const [submissionsList, setSubmissionsList] = useState([]);
  const [resultsLoading, setResultsLoading] = useState(false);
  const [exporting, setExporting] = useState(false);

  // Filters & Selected Respondent
  const [statusFilter, setStatusFilter] = useState('all'); // 'all' | 'completed' | 'process'
  const [respondentSearch, setRespondentSearch] = useState('');
  const [selectedRespondent, setSelectedRespondent] = useState(null);
  const [confirmDeleteForm, setConfirmDeleteForm] = useState(null); // objek form yang mau dihapus

  // Aktivitas Saya (baru) — daftar form yang pernah/lagi diisi sebagai responden
  const [mySubmissions, setMySubmissions] = useState([]);
  const [activityLoading, setActivityLoading] = useState(false);
  const [activitySearch, setActivitySearch] = useState('');
  const [activityFilter, setActivityFilter] = useState('all'); // all | completed | in_progress | cheated
  const [activityResult, setActivityResult] = useState(null);
  const [activityResultLoading, setActivityResultLoading] = useState(false);
  const [activityDetailSub, setActivityDetailSub] = useState(null); // submission yang sedang dilihat detail/bukti

  const token = localStorage.getItem('token');

  const fetchTemplates = async () => {
    try {
      const tpls = await getTemplates(token);
      setTemplates(tpls);
    } catch {
      // diamkan, biar tidak blokir dashboard
    }
  };

  useEffect(() => {
    if (!token) {
      navigate('/auth');
      return;
    }
    // FIX: eager fetch template di dashboard mount biar tidak flash Indonesia→Inggris
    // Deterministik: backend sudah asc, tapi tetap client sort untuk jaga bila DB lama
    Promise.all([
      getMe(token),
      getMyForms(token).catch(() => []),
      getTemplates(token).catch(() => []),
    ])
      .then(([userData, forms, tpls]) => {
        setUser(userData);
        const sorted = [...forms].sort((a, b) => parseServerTime(b.created_at) - parseServerTime(a.created_at));
        setAllForms(sorted);
        setRecentForms(sorted.slice(0, 3));
        if (Array.isArray(tpls)) setTemplates(tpls);
      })
      .catch(() => {
        logout();
        navigate('/auth');
      })
      .finally(() => setLoading(false));
  }, [navigate, token]);

  // FIX: auto-load template langsung tanpa F5 — handle pending + autoOpen + back reload
  useEffect(() => {
    if (location.state?.autoOpenTemplate || location.state?.reloadTemplates) {
      setActiveNav('template');
      window.history.replaceState({}, document.title);
    }
  }, [location.state]);

  // FIX: load template hanya saat tab Template dibuka (tidak saat refresh dashboard)
  // Juga cek pending template dari FormBuilder agar langsung muncul di "Template Saya" tanpa F5.
  useEffect(() => {
    if (activeNav === 'template' && token) {
      // Cek localStorage pending (ditulis FormBuilder saat konfirmasi simpan)
      try {
        const raw = localStorage.getItem('template-just-saved');
        if (raw) {
          const created = JSON.parse(raw);
          if (created && created.id) {
            setTemplates((prev) => (prev.some((t) => t.id === created.id) ? prev : [...prev, created]));
          }
          localStorage.removeItem('template-just-saved');
        }
      } catch {}
      // Juga cek location.state (navigasi dengan state)
      if (location.state?.newTemplate) {
        const nt = location.state.newTemplate;
        setTemplates((prev) => (prev.some((t) => t.id === nt.id) ? prev : [...prev, nt]));
      }
      fetchTemplates();
    }
  }, [activeNav, token]);

  // FIX: saat Dashboard pertama kali mount, cek apakah ada template pending dari save sebelumnya
  // agar "Template Saya" langsung terisi tanpa perlu buka tab dulu jika user baru save dan kembali.
  useEffect(() => {
    if (!token) return;
    // Jika datang dari FormBuilder dengan autoOpen, sudah handle di atas
    try {
      const raw = localStorage.getItem('template-just-saved');
      if (raw) {
        const created = JSON.parse(raw);
        if (created && created.id) {
          setTemplates((prev) => (prev.some((t) => t.id === created.id) ? prev : [...prev, created]));
        }
      }
    } catch {}
    if (location.state?.newTemplate) {
      const nt = location.state.newTemplate;
      setTemplates((prev) => (prev.some((t) => t.id === nt.id) ? prev : [...prev, nt]));
      if (location.state?.autoOpenTemplate) setActiveNav('template');
    }
  }, []);

  // FIX: dengarkan event "template-saved" dari FormBuilder agar template langsung muncul
  // "pada saat itu juga" tanpa perlu refresh manual.
  useEffect(() => {
    const onTemplateSaved = (e) => {
      const newTpl = e.detail;
      if (newTpl && newTpl.id) {
        setTemplates((prev) => {
          if (prev.some((t) => t.id === newTpl.id)) return prev;
          return [...prev, newTpl];
        });
      } else {
        fetchTemplates();
      }
    };
    const onStorage = (e) => {
      if (e.key === 'template-just-saved') fetchTemplates();
    };
    window.addEventListener('template-saved', onTemplateSaved);
    window.addEventListener('storage', onStorage);
    return () => {
      window.removeEventListener('template-saved', onTemplateSaved);
      window.removeEventListener('storage', onStorage);
    };
  }, [token]);

  // Close context menu when clicking outside
  useEffect(() => {
    const handleClick = (e) => {
      if (contextRef.current && !contextRef.current.contains(e.target)) {
        setContextMenu(null);
      }
    };
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  const showToast = (msg, isError = false) => {
    setToast({ msg, isError });
    setTimeout(() => setToast(null), 3000);
  };

  // Fetch Aktivitas Saya ketika tab dibuka
  const fetchMyActivity = async () => {
    if (!token) return;
    setActivityLoading(true);
    try {
      const data = await getMySubmissions(token);
      // sort terbaru di atas
      const sorted = [...(data || [])].sort((a, b) => parseServerTime(b.started_at) - parseServerTime(a.started_at));
      setMySubmissions(sorted);
    } catch (err) {
      showToast(err.message || 'Gagal memuat Aktivitas Saya', true);
    } finally {
      setActivityLoading(false);
    }
  };

  useEffect(() => {
    if (activeNav === 'activity' && mySubmissions.length === 0 && !activityLoading) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      fetchMyActivity();
    }
  }, [activeNav]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleViewMyResult = async (sub) => {
    if (!sub?.id) return;
    if (!sub.form?.allow_see_result) {
      showToast('Pembuat form tidak mengizinkan melihat hasil', true);
      return;
    }
    setActivityResultLoading(true);
    try {
      const data = await getSubmissionResult(token, sub.id);
      setActivityResult(data);
      setActivityDetailSub(sub);
    } catch (err) {
      showToast(err.message || 'Gagal mengambil hasil', true);
    } finally {
      setActivityResultLoading(false);
    }
  };

  const handleLogout = () => {
    logout();
    navigate('/auth');
  };

  const handleCreateBlank = () => {
    navigate('/form-builder');
  };

  const handleTemplateClick = (template) => {
    navigate(`/form-builder?template=${template.id}`);
  };

  const handleFormClick = (form) => {
    navigate(`/form-builder/${form.id}`);
  };

  const handleDeleteForm = async (formId) => {
    try {
      await deleteForm(token, formId);
      const updated = allForms.filter((f) => f.id !== formId);
      setAllForms(updated);
      setRecentForms(updated.slice(0, 3));
      setContextMenu(null);
      showToast('Form berhasil dihapus');
    } catch (err) {
      showToast(err.message, true);
    }
  };

  const handleConfirmDelete = async () => {
    if (!confirmDeleteForm) return;
    await handleDeleteForm(confirmDeleteForm.id);
    setConfirmDeleteForm(null);
  };

  const handleDeleteTemplate = async (templateId) => {
    try {
      await deleteTemplate(token, templateId);
      setTemplates((prev) => prev.filter((t) => t.id !== templateId));
      setContextMenu(null);
      showToast('Template berhasil dihapus');
    } catch (err) {
      showToast(err.message, true);
    }
  };

  // Open Full-Page Results View ("Lihat Hasil")
  const handleOpenResultsPage = async (form) => {
    setSelectedFormForResults(form);
    setHistorySubView('results');
    setResultsLoading(true);
    setSelectedRespondent(null);
    setRespondentSearch('');
    setStatusFilter('all');

    try {
      const [detail, subs] = await Promise.all([
        getForm(token, form.id),
        getFormSubmissions(token, form.id),
      ]);
      setFormDetail(detail);

      // Calculate Quiz scoring and duration for each submission
      const processedSubs = subs.map((sub) => {
        let correctCount = 0;
        let totalGradable = 0;

        const questions = (detail.questions || []).sort((a, b) => a.order_index - b.order_index);

        questions.forEach((q) => {
          const correctOpts = (q.options || []).filter((o) => o.is_correct).map((o) => o.label);
          if (correctOpts.length > 0) {
            totalGradable += 1;
            const ans = (sub.answers || []).find((a) => a.question_id === q.id);
            if (ans) {
              const userSelected = ans.answer_options || (ans.answer_text ? [ans.answer_text] : []);
              const isMatch =
                correctOpts.length === userSelected.length &&
                correctOpts.every((opt) => userSelected.includes(opt));
              if (isMatch) {
                correctCount += 1;
              }
            }
          }
        });

        const scorePercent = totalGradable > 0 ? Math.round((correctCount / totalGradable) * 100) : null;

        // Duration calculation
        let durationMinutes = 0;
        let durationStr = '-';
        if (sub.started_at && sub.submitted_at) {
          const diffMs = parseServerTime(sub.submitted_at).getTime() - parseServerTime(sub.started_at).getTime();
          const totalSecs = Math.max(0, Math.floor(diffMs / 1000));
          const mins = Math.floor(totalSecs / 60);
          const secs = totalSecs % 60;
          durationMinutes = mins;
          durationStr = mins > 0 ? `${mins}m ${secs}s` : `${secs}s`;
        }

        return {
          ...sub,
          correctCount,
          totalGradable,
          scorePercent,
          durationMinutes,
          durationStr,
          isCompleted: !!sub.submitted_at,
        };
      });

      setSubmissionsList(processedSubs);
    } catch (err) {
      showToast(err.message || 'Gagal memuat hasil respons', true);
    } finally {
      setResultsLoading(false);
    }
  };

  // Trigger Excel Download
  const handleExportExcel = async () => {
    if (!selectedFormForResults) return;
    try {
      setExporting(true);
      await exportSubmissions(token, selectedFormForResults.id, selectedFormForResults.slug);
      showToast('File Excel berhasil diunduh!');
    } catch (err) {
      showToast(err.message || 'Gagal mengekspor data', true);
    } finally {
      setExporting(false);
    }
  };

  const formatTimeAgo = (dateStr) => {
    if (!dateStr) return '';
    const now = new Date();
    const date = parseServerTime(dateStr);
    if (!date) return '';
    const diff = now - date;
    const mins = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);
    const weeks = Math.floor(days / 7);
    const months = Math.floor(days / 30);

    if (mins < 1) return 'Baru saja';
    if (mins < 60) return `${mins} menit lalu`;
    if (hours < 24) return `${hours} jam lalu`;
    if (days < 7) return `${days} hari lalu`;
    if (weeks < 4) return `${weeks} minggu lalu`;
    return `${months} bulan lalu`;
  };

  const formatDateString = (dateStr) => {
    if (!dateStr) return '-';
    const date = parseServerTime(dateStr);
    if (!date) return '-';
    return date.toLocaleString('id-ID', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getInitials = (name = '') =>
    name.split(' ').slice(0, 2).map((w) => w[0]).join('').toUpperCase();

  // Deterministik: backend asc, tapi client sort lagi untuk jaga bila DB lama / timestamp kembar
  // Keep seed Inggris (Blank/Attendance/Exam) — mobile tidak perlu migrasi, web mapping bilingual
  const systemTemplates = templates
    .filter((t) => t.is_system)
    .sort((a, b) => {
      const ca = parseServerTime(a.created_at)?.getTime() ?? 0;
      const cb = parseServerTime(b.created_at)?.getTime() ?? 0;
      if (ca !== cb) return ca - cb;
      const ta = (a.title || '').toLowerCase();
      const tb = (b.title || '').toLowerCase();
      if (ta !== tb) return ta.localeCompare(tb);
      return String(a.id).localeCompare(String(b.id));
    });

  const filteredForms = allForms.filter((f) =>
    f.title.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // Helper bilingual: form ujian <-> exam form , kehadiran <-> attendance , kosong <-> blank
  const matchesTemplateQuery = (t, qq) => {
    const title = (t.title || '').toLowerCase();
    const desc = (t.description || '').toLowerCase();
    if (title.includes(qq) || desc.includes(qq)) return true;
    // alias Indonesia <-> Inggris
    const aliases = {
      'ujian': ['exam'],
      'exam': ['ujian'],
      'kehadiran': ['attendance'],
      'attendance': ['kehadiran'],
      'kosong': ['blank'],
      'blank': ['kosong'],
    };
    for (const [k, vals] of Object.entries(aliases)) {
      if (qq.includes(k) && vals.some((v) => title.includes(v) || desc.includes(v))) return true;
    }
    return false;
  };

  // Search untuk Dasbor & Templat (sebelumnya hanya Riwayat yang jalan)
  const q = searchQuery.trim().toLowerCase();
  const filteredSystemTemplates = q
    ? systemTemplates.filter((t) => matchesTemplateQuery(t, q))
    : systemTemplates;
  const filteredRecentForms = q ? filteredForms.slice(0, 6) : recentForms;
  const filteredTemplates = q
    ? templates.filter(
        (t) => t.title.toLowerCase().includes(q) || (t.description && t.description.toLowerCase().includes(q))
      )
    : templates;

  // Filter respondents by search & status
  const filteredRespondents = submissionsList.filter((sub) => {
    const name = sub.user?.full_name || 'Responden (User)';
    const email = sub.user?.email || '';
    const matchesSearch =
      name.toLowerCase().includes(respondentSearch.toLowerCase()) ||
      email.toLowerCase().includes(respondentSearch.toLowerCase());

    if (!matchesSearch) return false;
    if (statusFilter === 'completed') return sub.isCompleted && !sub.is_cheated;
    if (statusFilter === 'process') return !sub.isCompleted && !sub.is_cheated;
    if (statusFilter === 'cheated') return !!sub.is_cheated;
    return true;
  });

  // Calculate Overall Stats for View 1
  const totalRespondents = submissionsList.length;
  const scoredSubs = submissionsList.filter((s) => s.scorePercent !== null);
  const avgScore =
    scoredSubs.length > 0
      ? Math.round(scoredSubs.reduce((acc, curr) => acc + curr.scorePercent, 0) / scoredSubs.length)
      : null;

  const completedSubs = submissionsList.filter((s) => s.isCompleted);
  const avgDuration =
    completedSubs.length > 0
      ? Math.round(completedSubs.reduce((acc, curr) => acc + curr.durationMinutes, 0) / completedSubs.length)
      : 0;

  if (loading) {
    return (
      <div className="db-loading">
        <div className="db-spinner" />
        <p>Memuat dashboard...</p>
      </div>
    );
  }

  return (
    <div className="db-root">
      {/* Sidebar - Preserved and always active */}
      <aside className="db-sidebar">
        <div className="db-logo">
          <div className="db-logo-icon">
            <img src={logoForm4x} alt="Form4x logo" className="db-logo-img" />
          </div>
          <div className="db-logo-text">
            <span className="db-logo-name">Form4x</span>
            <span className="db-logo-tagline">Tempat membuat Form Terlengkap</span>
          </div>
        </div>

        {/* Nav */}
        <nav className="db-nav">
          {[
            {
              key: 'dashboard',
              label: 'Dasbor',
              icon: (
                <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <rect x="3" y="3" width="7" height="7" rx="1" />
                  <rect x="14" y="3" width="7" height="7" rx="1" />
                  <rect x="3" y="14" width="7" height="7" rx="1" />
                  <rect x="14" y="14" width="7" height="7" rx="1" />
                </svg>
              ),
            },
            {
              key: 'template',
              label: 'Templat',
              icon: (
                <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <rect x="3" y="3" width="18" height="18" rx="2" />
                  <path d="M3 9h18M9 21V9" />
                </svg>
              ),
            },
            {
              key: 'history',
              label: 'Riwayat',
              icon: (
                <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <polyline points="1 4 1 10 7 10" />
                  <path d="M3.51 15a9 9 0 1 0 .49-4.39" />
                </svg>
              ),
            },
            {
              key: 'activity',
              label: 'Aktivitas Saya',
              icon: (
                <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path d="M16 4h2a2 2 0 012 2v14a2 2 0 01-2 2H6a2 2 0 01-2-2V6a2 2 0 012-2h2" />
                  <rect x="8" y="2" width="8" height="4" rx="1" />
                  <path d="M9 14l2 2 4-4" />
                </svg>
              ),
            },
          ].map((item) => (
            <button
              key={item.key}
              id={`nav-${item.key}`}
              className={`db-nav-item ${activeNav === item.key ? 'active' : ''}`}
              onClick={() => {
                setActiveNav(item.key);
                setHistorySubView('list');
                setActivityResult(null);
                setActivityDetailSub(null);
              }}
            >
              {item.icon}
              <span>{item.label}</span>
            </button>
          ))}
        </nav>

        {/* User Footer */}
        <div className="db-sidebar-footer">
          <div
            className="db-user"
            onClick={() => navigate('/profile')}
            title="Lihat & Edit Profil"
            style={{ cursor: 'pointer' }}
          >
            <div className="db-avatar">
              {user?.avatar_url ? (
                <img src={user.avatar_url} alt={user.full_name} />
              ) : (
                <span>{getInitials(user?.full_name)}</span>
              )}
            </div>
            <div className="db-user-info">
              <span className="db-user-name">{user?.full_name}</span>
              <span className="db-user-email">{user?.email}</span>
            </div>
          </div>
          <button id="btn-logout" className="db-logout-btn" onClick={handleLogout} aria-label="Logout">
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" />
              <polyline points="16 17 21 12 16 7" />
              <line x1="21" y1="12" x2="9" y2="12" />
            </svg>
          </button>
        </div>
      </aside>

      {/* Main Content Panel */}
      <main className="db-main">
        {/* Topbar */}
        <header className="db-topbar">
          {!(activeNav === 'history' && (historySubView === 'results' || historySubView === 'detail')) && (
            <div className="db-search-wrap">
              <svg className="db-search-icon" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <circle cx="11" cy="11" r="8" />
                <line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
              <input
                id="search-input"
                className="db-search"
                type="text"
                placeholder="Cari formulir..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
          )}
          <ThemeToggle />
        </header>

        {/* Content Area */}
        <section className="db-content">
          {/* ===== DASHBOARD VIEW ===== */}
          {activeNav === 'dashboard' && (
            <>
              <div className="db-templates-row">
                <button id="btn-create-blank" className="db-card-create" onClick={handleCreateBlank}>
                  <div className="db-create-icon">
                    <svg width="28" height="28" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                      <circle cx="12" cy="12" r="10" />
                      <line x1="12" y1="8" x2="12" y2="16" />
                      <line x1="8" y1="12" x2="16" y2="12" />
                    </svg>
                  </div>
                  <span>Buat Templat Baru</span>
                </button>

                {filteredSystemTemplates.length > 0 ? (
                  filteredSystemTemplates.map((tpl) => {
                    // Deterministik per title, bukan idx — fix klik form ujian malah kosong saat order shuffle
                    const lower = (tpl.title || '').toLowerCase();
                    const isBlank = lower.includes('kosong') || lower.includes('blank');
                    const isAttendance = lower.includes('hadir') || lower.includes('attendance');
                    const isExam = lower.includes('ujian') || lower.includes('exam');
                    const bgClass = isBlank ? 'blank-bg' : isAttendance ? 'attendance-bg' : 'exam-bg';
                    const subtitle = isBlank ? 'Mulai dari kosong' : isAttendance ? 'Pelacakan acara atau kelas' : 'Penilaian & Kuis';
                    const showBadge = isExam;
                    return (
                      <div
                        key={tpl.id}
                        className="db-card-system"
                        onClick={() => handleTemplateClick(tpl)}
                      >
                        <div className={`db-card-preview ${bgClass}`}>
                          {showBadge && (
                            <span className="db-badge">
                              <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                                <circle cx="12" cy="12" r="10" />
                                <polyline points="12 6 12 12 16 14" />
                              </svg>
                              Timer Aktif
                            </span>
                          )}
                          <div className="db-preview-doc">
                            <div className="db-preview-line db-line-wide" />
                            <div className="db-preview-line db-line-mid" />
                            <div className="db-preview-line db-line-short" />
                            <div className="db-preview-line db-line-mid" />
                          </div>
                        </div>
                        <div className="db-card-info">
                          <p className="db-card-title">{stripHtml(tpl.title)}</p>
                          <p className="db-card-subtitle">{subtitle}</p>
                        </div>
                      </div>
                    );
                  })
                ) : q ? (
                  <div className="db-empty-state" style={{ gridColumn: 'span 3', padding: '24px' }}>
                    <p>Tidak ada template untuk "{searchQuery}"</p>
                  </div>
                ) : loading ? (
                  <div className="db-empty-state" style={{ gridColumn: 'span 3', padding: '24px' }}>
                    <div className="db-spinner" style={{ margin: '0 auto 12px' }} />
                    <p>Memuat template...</p>
                  </div>
                ) : (
                  <>
                    {[
                      { title: 'Form Kosong', subtitle: 'Mulai dari kosong', bg: 'blank-bg' },
                      { title: 'Form Kehadiran', subtitle: 'Pelacakan acara atau kelas', bg: 'attendance-bg' },
                      { title: 'Form Ujian', subtitle: 'Penilaian & Kuis', bg: 'exam-bg', badge: true },
                    ].map((card, idx) => (
                      <div key={idx} className="db-card-system" onClick={handleCreateBlank}>
                        <div className={`db-card-preview ${card.bg}`}>
                          {card.badge && (
                            <span className="db-badge">
                              <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                                <circle cx="12" cy="12" r="10" />
                                <polyline points="12 6 12 12 16 14" />
                              </svg>
                              Timer Aktif
                            </span>
                          )}
                          <div className="db-preview-doc">
                            <div className="db-preview-line db-line-wide" />
                            <div className="db-preview-line db-line-mid" />
                            <div className="db-preview-line db-line-short" />
                            <div className="db-preview-line db-line-mid" />
                          </div>
                        </div>
                        <div className="db-card-info">
                          <p className="db-card-title">{stripHtml(card.title)}</p>
                          <p className="db-card-subtitle">{card.subtitle}</p>
                        </div>
                      </div>
                    ))}
                  </>
                )}
              </div>

              {/* Riwayat Terbaru */}
              <h2 className="db-section-title">Riwayat Terbaru</h2>
              {filteredRecentForms.length > 0 ? (
                <div className="db-recent-grid">
                  {filteredRecentForms.map((form) => (
                    <div key={form.id} className="db-recent-card" onClick={() => handleFormClick(form)}>
                      <div className="db-recent-preview">
                        {form.banner_url ? (
                          <NgrokImage src={form.banner_url} alt={form.title} className="db-recent-banner" />
                        ) : (
                          <div className="db-preview-doc">
                            <div className="db-preview-line db-line-wide" />
                            <div className="db-preview-line db-line-mid" />
                            <div className="db-preview-line db-line-short" />
                          </div>
                        )}
                      </div>
                      <div className="db-recent-footer">
                        <div>
                          <p className="db-recent-title">{stripHtml(form.title)}</p>
                          <p className="db-recent-date">Diperbarui {formatTimeAgo(form.created_at)}</p>
                        </div>
                        <div style={{ position: 'relative' }}>
                          <button
                            className="db-card-menu"
                            aria-label="Options"
                            onClick={(e) => {
                              e.stopPropagation();
                              setContextMenu(contextMenu?.type === 'form' && contextMenu.id === form.id ? null : { type: 'form', id: form.id });
                            }}
                          >
                            <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                              <circle cx="12" cy="5" r="1.5" />
                              <circle cx="12" cy="12" r="1.5" />
                              <circle cx="12" cy="19" r="1.5" />
                            </svg>
                          </button>
                          {contextMenu?.type === 'form' && contextMenu.id === form.id && (
                            <div className="db-context-menu" ref={contextRef}>
                              <button className="db-context-item" onClick={(e) => { e.stopPropagation(); handleFormClick(form); }}>
                                <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                  <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7" />
                                  <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z" />
                                </svg>
                                Edit
                              </button>
                              <button className="db-context-item danger" onClick={(e) => { e.stopPropagation(); setConfirmDeleteForm(form); }}>
                                <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                  <polyline points="3 6 5 6 21 6" />
                                  <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                                </svg>
                                Hapus
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : q ? (
                <div className="db-empty-state">
                  <p>Tidak ada form untuk "{searchQuery}"</p>
                </div>
              ) : (
                <div className="db-empty-state">
                  <svg width="48" height="48" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                    <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
                    <polyline points="14 2 14 8 20 8" />
                  </svg>
                  <p>Belum ada form. Mulai buat form pertamamu!</p>
                </div>
              )}
            </>
          )}

          {/* ===== TEMPLATE VIEW ===== */}
          {activeNav === 'template' && (
            <>
              <h2 className="db-section-title">Semua Templat</h2>
              {filteredTemplates.length > 0 ? (
                <div className="db-recent-grid">
                  {filteredTemplates.map((tpl) => (
                    <div key={tpl.id} className="db-recent-card" onClick={() => handleTemplateClick(tpl)}>
                      <div className="db-recent-preview">
                        {tpl.banner_url ? (
                          <NgrokImage src={tpl.banner_url} alt={tpl.title} className="db-recent-banner" />
                        ) : (
                          <div className="db-preview-doc">
                            <div className="db-preview-line db-line-wide" />
                            <div className="db-preview-line db-line-mid" />
                            <div className="db-preview-line db-line-short" />
                          </div>
                        )}
                      </div>
                      <div className="db-recent-footer">
                        <div>
                          <p className="db-recent-title">{stripHtml(tpl.title)}</p>
                          <p className="db-recent-date">{tpl.is_system ? 'Templat Sistem' : 'Templat Saya'}</p>
                        </div>
                        {!tpl.is_system && (
                          <div style={{ position: 'relative' }}>
                            <button
                              className="db-card-menu"
                              aria-label="Options"
                              onClick={(e) => {
                                e.stopPropagation();
                                setContextMenu(contextMenu?.type === 'template' && contextMenu.id === tpl.id ? null : { type: 'template', id: tpl.id });
                              }}
                            >
                              <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                                <circle cx="12" cy="5" r="1.5" />
                                <circle cx="12" cy="12" r="1.5" />
                                <circle cx="12" cy="19" r="1.5" />
                              </svg>
                            </button>
                            {contextMenu?.type === 'template' && contextMenu.id === tpl.id && (
                              <div className="db-context-menu" ref={contextRef}>
                                <button className="db-context-item danger" onClick={(e) => { e.stopPropagation(); handleDeleteTemplate(tpl.id); }}>
                                  <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                    <polyline points="3 6 5 6 21 6" />
                                    <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                                  </svg>
                                  Hapus
                                </button>
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              ) : q ? (
                <div className="db-empty-state">
                  <p>Tidak ada template untuk "{searchQuery}"</p>
                </div>
              ) : (
                <div className="db-empty-state">
                  <svg width="48" height="48" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                    <rect x="3" y="3" width="18" height="18" rx="2" />
                    <path d="M3 9h18M9 21V9" />
                  </svg>
                  <p>Belum ada template</p>
                </div>
              )}
            </>
          )}

          {/* ===== HISTORY VIEW ===== */}
          {activeNav === 'history' && (
            <>
              {/* SUBVIEW 1: FORM CARDS GRID */}
              {historySubView === 'list' && (
                <>
                  <h2 className="db-section-title">Riwayat Form</h2>
                  {filteredForms.length > 0 ? (
                    <div className="history-card-grid">
                      {filteredForms.map((form) => (
                        <div key={form.id} className="history-card">
                          <div className="history-card-preview">
                            {form.banner_url ? (
                              <NgrokImage src={form.banner_url} alt={form.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                            ) : (
                              <div className="db-preview-doc">
                                <div className="db-preview-line db-line-wide" />
                                <div className="db-preview-line db-line-mid" />
                                <div className="db-preview-line db-line-short" />
                              </div>
                            )}
                          </div>
                          <div style={{ position: 'absolute', top: 10, right: 10, zIndex: 5 }}>
                            <button
                              className="db-card-menu history-card-menu"
                              aria-label="Opsi Form"
                              onClick={(e) => {
                                e.stopPropagation();
                                setContextMenu(contextMenu?.type === 'form' && contextMenu.id === form.id ? null : { type: 'form', id: form.id });
                              }}
                            >
                              <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                                <circle cx="12" cy="5" r="1.5" />
                                <circle cx="12" cy="12" r="1.5" />
                                <circle cx="12" cy="19" r="1.5" />
                              </svg>
                            </button>
                            {contextMenu?.type === 'form' && contextMenu.id === form.id && (
                              <div className="db-context-menu" ref={contextRef}>
                                <button className="db-context-item" onClick={(e) => { e.stopPropagation(); handleFormClick(form); }}>
                                  <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                    <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7" />
                                    <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z" />
                                  </svg>
                                  Edit
                                </button>
                                <button className="db-context-item danger" onClick={(e) => { e.stopPropagation(); setConfirmDeleteForm(form); }}>
                                  <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                    <polyline points="3 6 5 6 21 6" />
                                    <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                                  </svg>
                                  Hapus
                                </button>
                              </div>
                            )}
                          </div>
                          <div className="history-card-body">
                            <div className="history-card-info">
                              <h3 className="history-card-title" title={stripHtml(form.title)}>{stripHtml(form.title)}</h3>
                              <div className="history-card-status-wrap">
                                <span className={`db-status ${form.status}`}>{form.status}</span>
                              </div>
                              <span className="history-card-responses-text">{form.total_submissions} Respons</span>
                            </div>
                            <button
                              className="history-btn-result"
                              onClick={() => handleOpenResultsPage(form)}
                            >
                              Lihat Hasil
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="db-empty-state">
                      <svg width="48" height="48" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                        <polyline points="1 4 1 10 7 10" />
                        <path d="M3.51 15a9 9 0 1 0 .49-4.39" />
                      </svg>
                      <p>Belum ada riwayat form</p>
                    </div>
                  )}
                </>
              )}

              {/* SUBVIEW 2: HASIL RESPONDEN (Image 1 Mockup) */}
              {historySubView === 'results' && selectedFormForResults && (
                <div className="results-page-container">
                  {/* Top Bar Navigation & Header */}
                  <div className="results-header-row">
                    <div className="results-header-titles">
                      <button
                        className="back-nav-btn"
                        onClick={() => setHistorySubView('list')}
                        style={{ marginBottom: '8px' }}
                      >
                        ← Kembali ke Riwayat Form
                      </button>
                      <h2>Riwayat Form</h2>
                      <p>Hasil Responden - <strong>{stripHtml(selectedFormForResults.title)}</strong></p>
                    </div>

                    <button
                      className="btn-export-excel"
                      onClick={handleExportExcel}
                      disabled={exporting || submissionsList.length === 0}
                    >
                      <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                      </svg>
                      <span>{exporting ? 'Mengekspor...' : 'Ekspor ke Excel'}</span>
                    </button>
                  </div>

                  {/* Score Analysis Top Banner Row matching mockup (Total Respons, Nilai Tertinggi, Nilai Terendah) */}
                  {(() => {
                    // Highest & Lowest scores calculation
                    const highestScore = scoredSubs.length > 0 ? Math.max(...scoredSubs.map((s) => s.scorePercent)) : '-';
                    const lowestScore = scoredSubs.length > 0 ? Math.min(...scoredSubs.map((s) => s.scorePercent)) : '-';

                    return (
                      <div className="score-analysis-top-banner">
                        <div className="score-top-item">
                          <span className="score-top-num">{totalRespondents}</span>
                          <span className="score-top-lbl">TOTAL RESPONS</span>
                        </div>
                        <div className="score-top-divider" />
                        <div className="score-top-item">
                          <span className="score-top-num">{highestScore}</span>
                          <span className="score-top-lbl">NILAI TERTINGGI</span>
                        </div>
                        <div className="score-top-divider" />
                        <div className="score-top-item">
                          <span className="score-top-num">{lowestScore}</span>
                          <span className="score-top-lbl">NILAI TERENDAH</span>
                        </div>
                      </div>
                    );
                  })()}

                  {/* Table Card Container */}
                  <div className="table-card-container">
                    <div className="table-card-header">
                      <h3 className="table-card-title">Daftar Responden</h3>
                      <div className="table-header-filters">
                        <input
                          type="text"
                          className="db-search"
                          placeholder="Cari nama atau email..."
                          value={respondentSearch}
                          onChange={(e) => setRespondentSearch(e.target.value)}
                          style={{ width: '220px', padding: '6px 12px', fontSize: '13px' }}
                        />
                        <select
                          className="filter-select"
                          value={statusFilter}
                          onChange={(e) => setStatusFilter(e.target.value)}
                        >
                          <option value="all">Semua Status</option>
                          <option value="completed">Selesai</option>
                          <option value="process">Proses</option>
                          <option value="cheated">Curang</option>
                        </select>
                      </div>
                    </div>

                    {resultsLoading ? (
                      <div style={{ textAlign: 'center', padding: '48px 0', color: '#64748B' }}>
                        <div className="db-spinner" style={{ margin: '0 auto 12px' }} />
                        <p>Memuat daftar responden...</p>
                      </div>
                    ) : filteredRespondents.length === 0 ? (
                      <div className="db-empty-state" style={{ padding: '40px 0' }}>
                        <p>Belum ada data responden yang sesuai.</p>
                      </div>
                    ) : (
                      <div className="resp-table-wrap">
                        <table className="resp-data-table">
                          <thead>
                            <tr>
                              <th>NAMA</th>
                              <th>EMAIL</th>
                              <th>TANGGAL SUBMIT</th>
                              <th>SKOR</th>
                              <th>STATUS</th>
                              <th style={{ textAlign: 'right' }}>AKSI</th>
                            </tr>
                          </thead>
                          <tbody>
                            {filteredRespondents.map((sub) => {
                              const name = sub.user?.full_name || 'Responden (User)';
                              const email = sub.user?.email || '-';
                              const isCompleted = sub.isCompleted;

                              return (
                                <tr key={sub.id}>
                                  <td className="td-user-name">{name}</td>
                                  <td className="td-user-email">{email}</td>
                                  <td>{formatDateString(sub.submitted_at || sub.started_at)}</td>
                                  <td className="td-score-val">
                                    {sub.scorePercent !== null ? `${sub.scorePercent}/100` : '-'}
                                  </td>
                                  <td>
                                    {sub.is_cheated ? (
                                      <span className="status-pill cheated" title="Responden keluar dari mode full screen">
                                        • Curang
                                      </span>
                                    ) : (
                                      <span className={`status-pill ${isCompleted ? 'completed' : 'process'}`}>
                                        • {isCompleted ? 'Selesai' : 'Proses'}
                                      </span>
                                    )}
                                  </td>
                                  <td style={{ textAlign: 'right' }}>
                                    <button
                                      className="btn-table-view"
                                      onClick={() => {
                                        setSelectedRespondent(sub);
                                        setHistorySubView('detail');
                                      }}
                                    >
                                      Lihat Jawaban »
                                    </button>
                                  </td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      </div>
                    )}

                    <div className="table-card-footer">
                      <span>
                        Menampilkan {filteredRespondents.length > 0 ? 1 : 0}-{filteredRespondents.length} dari {totalRespondents} responden
                      </span>
                      <div className="pagination-arrows">
                        <button className="pagination-btn" disabled>‹</button>
                        <button className="pagination-btn" disabled>›</button>
                      </div>
                    </div>
                  </div>

                  {/* 2 Score & Type Analysis Cards (Matching Mockup) */}
                  {(() => {
                    // Score distribution buckets
                    const scoreRanges = [
                      { label: '90-100', min: 90, max: 100 },
                      { label: '80-89', min: 80, max: 89 },
                      { label: '70-79', min: 70, max: 79 },
                      { label: '<70', min: 0, max: 69 },
                    ];
                    const scoreBuckets = scoreRanges.map((range) => {
                      const count = scoredSubs.filter(
                        (s) => s.scorePercent >= range.min && s.scorePercent <= range.max
                      ).length;
                      return { ...range, count };
                    });
                    const maxBucketCount = Math.max(...scoreBuckets.map((b) => b.count), 1);

                    // Assessment type (auto vs manual — auto = has gradable questions)
                    const autoCount = submissionsList.filter((s) => s.totalGradable > 0).length;
                    const manualCount = submissionsList.length - autoCount;
                    const total = submissionsList.length;
                    const autoPercent = total > 0 ? Math.round((autoCount / total) * 100) : 0;
                    const manualPercent = total > 0 ? 100 - autoPercent : 0;

                    return (
                      <div className="score-analysis-charts-row">
                        {/* Card 1: Distribusi Tipe Penilaian */}
                        <div className="score-chart-card">
                          <div className="score-chart-header">
                            <h4 className="score-chart-title">Distribusi Tipe Penilaian</h4>
                          </div>
                          <div className="score-donut-body">
                            <div className="score-donut-ring-wrap">
                              <svg viewBox="0 0 120 120" className="score-donut-svg">
                                <circle cx="60" cy="60" r="48" fill="none" stroke="#e2e8f0" strokeWidth="18" />
                                <circle
                                  cx="60" cy="60" r="48"
                                  fill="none"
                                  stroke="#0053db"
                                  strokeWidth="18"
                                  strokeDasharray={`${autoPercent * 3.016} ${300 - autoPercent * 3.016}`}
                                  strokeDashoffset="75"
                                  strokeLinecap="round"
                                />
                                {manualCount > 0 && (
                                  <circle
                                    cx="60" cy="60" r="48"
                                    fill="none"
                                    stroke="#10b981"
                                    strokeWidth="18"
                                    strokeDasharray={`${manualPercent * 3.016} ${300 - manualPercent * 3.016}`}
                                    strokeDashoffset={75 - autoPercent * 3.016}
                                    strokeLinecap="round"
                                  />
                                )}
                                <text x="60" y="54" textAnchor="middle" className="score-donut-center-val">{total}</text>
                                <text x="60" y="70" textAnchor="middle" className="score-donut-center-label">Total</text>
                              </svg>
                            </div>
                            <div className="score-donut-legend">
                              <div className="score-donut-legend-item">
                                <span className="score-donut-dot dot-auto" />
                                <span className="score-donut-legend-text">Otomatis</span>
                                <span className="score-donut-legend-count">{autoCount}</span>
                              </div>
                              <div className="score-donut-legend-item">
                                <span className="score-donut-dot dot-manual" />
                                <span className="score-donut-legend-text">Manual</span>
                                <span className="score-donut-legend-count">{manualCount}</span>
                              </div>
                            </div>
                          </div>
                        </div>

                        {/* Card 2: Score Analysis Bars */}
                        <div className="score-chart-card">
                          <div className="score-chart-header">
                            <h4 className="score-chart-title">Score Analysis</h4>
                          </div>
                          <div className="score-bars-container">
                            {scoreBuckets.map((bucket, bIdx) => (
                              <div key={bIdx} className="score-bar-column">
                                <div className={`score-bar-count-badge ${bucket.count > 0 ? 'active' : ''}`}>
                                  ✓ {bucket.count} Org
                                </div>
                                <div className="score-bar-track-vertical">
                                  <div
                                    className={`score-bar-fill-vertical ${bIdx === 0 ? 'striped-green' : 'striped-blue'}`}
                                    style={{
                                      height: `${Math.max((bucket.count / maxBucketCount) * 100, bucket.count > 0 ? 25 : 0)}%`,
                                    }}
                                  />
                                </div>
                                <span className="score-bar-range-label">{bucket.label}</span>
                              </div>
                            ))}
                          </div>
                        </div>
                      </div>
                    );
                  })()}

                  {/* Visual Analytics & Question Summary Charts */}
                  <div className="analytics-section">
                    <div className="analytics-section-header">
                      <div>
                        <h3 className="analytics-section-title">
                          <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M9 19v-6a2 2 0 012-2h2a2 2 0 012 2v6m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2" />
                          </svg>
                          Ringkasan & Visualisasi Jawaban
                        </h3>
                        <p className="analytics-section-subtitle">Analisis statistik distribusi jawaban responden per pertanyaan</p>
                      </div>
                    </div>

                    <div className="analytics-questions-grid">
                      {(formDetail?.questions || [])
                        .sort((a, b) => a.order_index - b.order_index)
                        .map((q, idx) => {
                          const typeLabels = {
                            text: 'Teks', single_choice: 'Pilihan Ganda', checkbox: 'Checkbox',
                            dropdown: 'Dropdown', date: 'Tanggal', file_upload: 'Upload File',
                          };

                          // Find all answers for this question across all submissions
                          const allAnsForQ = submissionsList
                            .map((sub) => ({
                              ans: (sub.answers || []).find((a) => a.question_id === q.id),
                              user: sub.user,
                              submittedAt: sub.submitted_at,
                            }))
                            .filter((item) => {
                              const a = item.ans;
                              if (!a) return false;
                              return !!(a.answer_text || (Array.isArray(a.answer_options) && a.answer_options.length > 0) || a.file_url);
                            });

                          const answeredCountForQ = allAnsForQ.length;
                          const isOptionType = ['single_choice', 'checkbox', 'dropdown'].includes(q.type) && q.options?.length > 0;
                          const colorPalette = [
                            'linear-gradient(90deg, #0053db, #2563eb)',
                            'linear-gradient(90deg, #10b981, #059669)',
                            'linear-gradient(90deg, #f59e0b, #d97706)',
                            'linear-gradient(90deg, #8b5cf6, #7c3aed)',
                            'linear-gradient(90deg, #ec4899, #db2777)',
                            'linear-gradient(90deg, #6366f1, #4f46e5)',
                          ];

                          return (
                            <div key={q.id} className="analytics-question-card">
                              <div className="analytics-q-header">
                                <h4 className="analytics-q-title" title={plainLabel(q.label)}>
                                  {idx + 1}. {plainLabel(q.label)}
                                </h4>
                                <div className="analytics-q-tags">
                                  <span className="analytics-type-badge">{typeLabels[q.type] || q.type}</span>
                                  <span className="analytics-resp-badge">{answeredCountForQ} Respons</span>
                                </div>
                              </div>

                              {/* Option Charts */}
                              {isOptionType ? (
                                <div className="analytics-chart-wrap">
                                  {q.options.map((opt, oIdx) => {
                                    // Calculate how many respondents picked this option
                                    const pickCount = allAnsForQ.filter((item) => {
                                      const a = item.ans;
                                      if (Array.isArray(a.answer_options)) {
                                        return a.answer_options.includes(opt.label);
                                      }
                                      return a.answer_text === opt.label;
                                    }).length;

                                    const percent = answeredCountForQ > 0 ? Math.round((pickCount / answeredCountForQ) * 100) : 0;
                                    const gradient = colorPalette[oIdx % colorPalette.length];

                                    return (
                                      <div key={opt.id} className="analytics-bar-item">
                                        <div className="analytics-bar-info">
                                          <div className="analytics-opt-label">
                                            <span>{stripHtml(opt.label)}</span>
                                            {opt.is_correct && <span className="analytics-correct-key">✓ Kunci Jawaban</span>}
                                          </div>
                                          <span className="analytics-opt-stats">
                                            <strong>{percent}%</strong> ({pickCount} responden)
                                          </span>
                                        </div>
                                        <div className="analytics-bar-track">
                                          <div
                                            className="analytics-bar-fill"
                                            style={{
                                              width: `${percent}%`,
                                              background: gradient,
                                            }}
                                          />
                                        </div>
                                      </div>
                                    );
                                  })}
                                </div>
                              ) : (
                                /* Text / Date / File Upload feed summary */
                                <div className="analytics-text-feed">
                                  {allAnsForQ.length === 0 ? (
                                    <p className="analytics-empty-text">Belum ada jawaban untuk pertanyaan ini.</p>
                                  ) : (
                                    allAnsForQ.slice(0, 5).map((item, itemIdx) => (
                                      <div key={itemIdx} className="analytics-feed-row">
                                        <div className="analytics-feed-user">
                                          <strong>{item.user?.full_name || 'Responden'}</strong>
                                          <span>• {item.submittedAt ? formatDateString(item.submittedAt) : 'Proses'}</span>
                                        </div>
                                        <div className="analytics-feed-ans">
                                          {q.type === 'file_upload' && item.ans.file_url ? (
                                            <a href={item.ans.file_url} target="_blank" rel="noopener noreferrer" style={{ color: '#0053db', fontWeight: 600 }}>
                                              Lihat File Upload ↗
                                            </a>
                                          ) : (
                                            item.ans.answer_text || '-'
                                          )}
                                        </div>
                                      </div>
                                    ))
                                  )}
                                  {allAnsForQ.length > 5 && (
                                    <div className="analytics-feed-more">
                                      + {allAnsForQ.length - 5} jawaban lainnya (lihat di detail responden)
                                    </div>
                                  )}
                                </div>
                              )}
                            </div>
                          );
                        })}
                    </div>
                  </div>
                </div>
              )}

              {/* SUBVIEW 3: INDIVIDUAL RESPONDENT ANSWER DETAIL — 2 kolom: kiri info, kanan jawaban scroll */}
              {historySubView === 'detail' && selectedRespondent && (
                <div className="results-page-container">
                  <button
                    className="back-nav-btn"
                    onClick={() => setHistorySubView('results')}
                  >
                    ← Kembali ke Daftar Responden
                  </button>

                  <div className="detail-layout">
                    {/* KIRI — Info ringkas rapih ke bawah (sticky) */}
                    <aside className="detail-info-card">
                      <div className="detail-info-header">
                        <span className="detail-info-kicker">Informasi Responden</span>
                        <h2 className="detail-info-title" title={stripHtml(formDetail?.title || selectedFormForResults?.title)}>
                          {stripHtml(formDetail?.title || selectedFormForResults?.title || 'Judul Form')}
                        </h2>
                      </div>

                      <div className="detail-info-list">
                        <div className="detail-info-row">
                          <span className="detail-info-label">
                            <svg width="13" height="13" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>
                            Nama
                          </span>
                          <strong className="detail-info-value">{selectedRespondent.user?.full_name || 'Responden (User)'}</strong>
                        </div>
                        <div className="detail-info-row">
                          <span className="detail-info-label">
                            <svg width="13" height="13" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>
                            Email
                          </span>
                          <strong className="detail-info-value" title={selectedRespondent.user?.email || '-'}>{selectedRespondent.user?.email || '-'}</strong>
                        </div>
                        <div className="detail-info-row">
                          <span className="detail-info-label">
                            <svg width="13" height="13" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                            Waktu Pengerjaan
                          </span>
                          <strong className="detail-info-value">{selectedRespondent.durationStr}</strong>
                        </div>
                        <div className="detail-info-row">
                          <span className="detail-info-label">
                            <svg width="13" height="13" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
                            Tanggal Submit
                          </span>
                          <strong className="detail-info-value">{formatDateString(selectedRespondent.submitted_at || selectedRespondent.started_at)} WIB</strong>
                        </div>
                        {selectedRespondent.is_cheated && (
                          <div className="detail-info-row cheated">
                            <span className="detail-info-label">
                              <svg width="13" height="13" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
                              Status
                            </span>
                            <strong className="detail-info-value cheated">Curang — keluar fullscreen</strong>
                          </div>
                        )}
                      </div>

                      {selectedRespondent.scorePercent !== null && (
                        <div className="detail-score-box left">
                          <p className="detail-score-label">Total Nilai</p>
                          <h3 className="detail-score-num">{selectedRespondent.scorePercent}/100</h3>
                        </div>
                      )}
                    </aside>

                    {/* KANAN — Hasil jawaban rapih ke bawah, bisa digulir */}
                    <section className="detail-answers-pane">
                      {/* Banner penanda curang (tetap di kanan juga) */}
                      {selectedRespondent.is_cheated && (
                        <div className="detail-cheated-banner">
                          <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                          </svg>
                          <span>
                            Responden ini terdeteksi <strong>curang</strong> karena keluar dari mode full screen saat mengisi form.
                          </span>
                        </div>
                      )}

                      <div className="detail-answers-list">
                    {(formDetail?.questions || [])
                      .sort((a, b) => a.order_index - b.order_index)
                      .map((q, idx) => {
                        const ans = (selectedRespondent.answers || []).find((a) => a.question_id === q.id);
                        const points = q.settings?.points || null;
                        const correctOpts = (q.options || []).filter((o) => o.is_correct).map((o) => o.label);
                        const isQuizQ = correctOpts.length > 0;
                        const userSelected = ans?.answer_options || (ans?.answer_text ? [ans.answer_text] : []);

                        // Type label for badge
                        const typeLabels = {
                          text: 'Teks', single_choice: 'Pilihan Ganda', checkbox: 'Checkbox',
                          dropdown: 'Dropdown', date: 'Tanggal', file_upload: 'Upload File',
                        };

                        // Determine if this question has renderable options (single_choice, checkbox, dropdown)
                        const hasOptionType = ['single_choice', 'checkbox', 'dropdown'].includes(q.type) && q.options?.length > 0;

                        return (
                          <div key={q.id} className="detail-question-card">
                            <div className="detail-question-header">
                              <h3 className="detail-question-title" title={plainLabel(q.label)}>
                                {idx + 1}. {plainLabel(q.label)}
                              </h3>
                              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexShrink: 0 }}>
                                <span style={{ background: '#f1f5f9', color: '#64748b', fontSize: '11px', fontWeight: 600, padding: '3px 10px', borderRadius: '6px' }}>
                                  {typeLabels[q.type] || q.type}
                                </span>
                                {points !== null && <span className="detail-points-badge">{points} Poin</span>}
                              </div>
                            </div>

                            {/* Option-based questions (single_choice, checkbox, dropdown) */}
                            {hasOptionType ? (
                              <div>
                                {q.options.map((opt) => {
                                  const isSelected = userSelected.includes(opt.label);
                                  const isCorrectKey = opt.is_correct;

                                  let cardClass = 'detail-option-card';
                                  if (isSelected && isCorrectKey) {
                                    cardClass += ' selected-correct';
                                  } else if (isSelected && !isCorrectKey && isQuizQ) {
                                    cardClass += ' selected-incorrect';
                                  } else if (isSelected && !isQuizQ) {
                                    cardClass += ' selected-correct';
                                  } else if (!isSelected && isCorrectKey && isQuizQ) {
                                    cardClass += ' is-correct-key';
                                  }

                                  return (
                                    <div key={opt.id} className={cardClass}>
                                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                                        <div
                                          style={{
                                            width: '18px',
                                            height: '18px',
                                            borderRadius: q.type === 'checkbox' ? '4px' : '50%',
                                            border: isSelected
                                              ? (isQuizQ ? (isCorrectKey ? '5px solid #0053DB' : '5px solid #E11D48') : '5px solid #0053DB')
                                              : '2px solid #CBD5E1',
                                            backgroundColor: isSelected ? '#FFFFFF' : 'transparent',
                                            flexShrink: 0,
                                          }}
                                        />
                                        <span>{stripHtml(opt.label)}</span>
                                      </div>

                                      {/* Indicator */}
                                      {isSelected && isQuizQ && isCorrectKey && (
                                        <div style={{ width: '22px', height: '22px', borderRadius: '50%', backgroundColor: '#0053DB', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px' }}>✓</div>
                                      )}
                                      {isSelected && isQuizQ && !isCorrectKey && (
                                        <div style={{ width: '22px', height: '22px', borderRadius: '50%', backgroundColor: '#E11D48', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px' }}>✕</div>
                                      )}
                                      {isSelected && !isQuizQ && (
                                        <div style={{ width: '22px', height: '22px', borderRadius: '50%', backgroundColor: '#0053DB', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px' }}>✓</div>
                                      )}
                                      {!isSelected && isCorrectKey && isQuizQ && (
                                        <span style={{ fontSize: '12px', color: '#16A34A', fontWeight: 600 }}>Kunci Jawaban</span>
                                      )}
                                    </div>
                                  );
                                })}
                              </div>
                            ) : q.type === 'text' ? (
                              /* Text Answer */
                              <div className="resp-answer-value">
                                {ans?.answer_text || <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Tidak dijawab</span>}
                              </div>
                            ) : q.type === 'date' ? (
                              /* Date Answer */
                              <div className="resp-answer-value" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                  <path strokeLinecap="round" strokeLinejoin="round" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                </svg>
                                {ans?.answer_text
                                  ? new Date(ans.answer_text).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })
                                  : <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Tidak dijawab</span>}
                              </div>
                            ) : q.type === 'file_upload' ? (
                              /* File Upload Answer */
                              <div className="resp-answer-value">
                                {ans?.file_url ? (
                                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                    <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="#0053db" strokeWidth={1.5}>
                                      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                                    </svg>
                                    <div>
                                      <span style={{ fontWeight: 600, color: '#0f172a', fontSize: '14px' }}>
                                        {ans.answer_text || 'File terlampir'}
                                      </span>
                                      <br />
                                      <a href={ans.file_url} target="_blank" rel="noopener noreferrer" style={{ color: '#0053db', fontWeight: 500, fontSize: '13px', textDecoration: 'none' }}>
                                        Unduh / Lihat File ↗
                                      </a>
                                    </div>
                                  </div>
                                ) : (
                                  <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Tidak ada file diupload</span>
                                )}
                              </div>
                            ) : (
                              /* Fallback for any other type */
                              <div className="resp-answer-value">
                                {ans?.answer_text || ans?.file_url || <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Tidak dijawab</span>}
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  </section>
                </div>
              </div>
              )}
            </>
          )}

          {/* ===== AKTIVITAS SAYA VIEW (Baru) ===== */}
          {activeNav === 'activity' && (
            <>
              {activityDetailSub && activityResult ? (
                // Detail hasil / bukti submit untuk satu aktivitas
                <div className="results-page-container">
                  <button className="back-nav-btn" onClick={() => { setActivityResult(null); setActivityDetailSub(null); }}>
                    ← Kembali ke Aktivitas Saya
                  </button>

                  <div className="detail-layout">
                    {/* KIRI — Info bukti rapih ke bawah */}
                    <aside className="detail-info-card">
                      <div className="detail-info-header">
                        <span className="detail-info-kicker">Bukti Pengisian</span>
                        <h2 className="detail-info-title" title={activityResult.form_title}>{activityResult.form_title}</h2>
                      </div>
                      <div className="detail-info-list">
                        {activityResult.score_percent !== null && (
                          <div className="detail-info-row" style={{ background: '#eff6ff', borderColor: '#bfdbfe' }}>
                            <span className="detail-info-label" style={{ color: '#0053db' }}>
                              <svg width="13" height="13" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                              Total Nilai
                            </span>
                            <strong className="detail-info-value" style={{ fontSize: '22px', color: '#0053db' }}>{activityResult.score_percent}/100 <span style={{ fontSize: '12px', fontWeight: 500, color: '#64748b' }}>({activityResult.correct_count}/{activityResult.total_graded} benar)</span></strong>
                          </div>
                        )}
                        <div className="detail-info-row">
                          <span className="detail-info-label">
                            <svg width="13" height="13" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
                            Waktu Submit
                          </span>
                          <strong className="detail-info-value">{formatDateString(activityResult.submitted_at)} WIB</strong>
                        </div>
                        <div className="detail-info-row">
                          <span className="detail-info-label">
                            <svg width="13" height="13" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                            Waktu Mulai
                          </span>
                          <strong className="detail-info-value">{formatDateString(activityDetailSub.started_at)} WIB</strong>
                        </div>
                        <div className="detail-info-row">
                          <span className="detail-info-label">
                            <svg width="13" height="13" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                            Durasi
                          </span>
                          <strong className="detail-info-value">
                            {(() => {
                              if (!activityDetailSub.started_at || !activityResult.submitted_at) return '-';
                              const diff = parseServerTime(activityResult.submitted_at).getTime() - parseServerTime(activityDetailSub.started_at).getTime();
                              const s = Math.max(0, Math.floor(diff / 1000));
                              const m = Math.floor(s / 60);
                              const sec = s % 60;
                              return m > 0 ? `${m}m ${sec}s` : `${sec}s`;
                            })()}
                          </strong>
                        </div>
                        <div className="detail-info-row">
                          <span className="detail-info-label">ID Submission</span>
                          <strong className="detail-info-value" title={activityDetailSub.id} style={{ fontFamily: 'monospace', fontSize: '12px' }}>{activityDetailSub.id}</strong>
                        </div>
                        {activityDetailSub.is_auto_submitted && (
                          <div className="detail-info-row" style={{ background: '#fffbeb', borderColor: '#fde68a' }}>
                            <span className="detail-info-label" style={{ color: '#b45309' }}>Status</span>
                            <strong className="detail-info-value" style={{ color: '#b45309' }}>⚡ Auto-submit (waktu habis)</strong>
                          </div>
                        )}
                        {activityDetailSub.is_cheated && (
                          <div className="detail-info-row cheated">
                            <span className="detail-info-label">Status</span>
                            <strong className="detail-info-value cheated">⚠️ Curang — keluar fullscreen</strong>
                          </div>
                        )}
                      </div>
                    </aside>

                    {/* KANAN — Rincian jawaban bisa digulir */}
                    <section className="detail-answers-pane">
                      <div className="detail-answers-list">
                    {activityResult.answers.map((a, idx) => (
                      <div key={a.question_id} className="detail-question-card">
                        <div className="detail-question-header">
                          <h3 className="detail-question-title">{idx + 1}. {plainLabel(a.label)}</h3>
                          {a.is_correct !== null && a.is_correct !== undefined && (
                            <span className={`correct-tag ${a.is_correct ? '' : 'incorrect-tag'}`} style={{ fontSize: '12px', fontWeight: 700, padding: '3px 10px', borderRadius: '9999px', background: a.is_correct ? '#dcfce7' : '#fee2e2', color: a.is_correct ? '#15803d' : '#b91c1c' }}>
                              {a.is_correct ? '✓ Benar' : '✕ Salah'}
                            </span>
                          )}
                        </div>
                        <div className="resp-answer-value">
                          <span style={{ fontSize: '12px', color: '#64748b', fontWeight: 600 }}>Jawaban kamu: </span>
                          <span style={{ color: '#0f172a', fontWeight: 500 }}>{stripHtml(a.user_answer) || <i style={{ color: '#94a3b8' }}>(tidak dijawab)</i>}</span>
                        </div>
                        {a.correct_answer && (
                          <div className="resp-answer-value" style={{ marginTop: '8px', background: '#f0fdf4', borderColor: '#bbf7d0' }}>
                            <span style={{ fontSize: '12px', color: '#15803d', fontWeight: 600 }}>Kunci: </span>
                            <span style={{ color: '#15803d' }}>{stripHtml(a.correct_answer)}</span>
                          </div>
                        )}
                      </div>
                    ))}
                      </div>
                    </section>
                  </div>
                </div>
              ) : (
                <>
                  <div className="results-header-row">
                    <div className="results-header-titles">
                      <h2>Aktivitas Saya</h2>
                      <p>Daftar form yang pernah / sedang kamu isi sebagai responden — bukti kapan submit dan statusnya</p>
                    </div>
                    <button className="btn-export-excel" style={{ background: '#2563eb' }} onClick={fetchMyActivity} disabled={activityLoading}>
                      <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                      </svg>
                      <span>{activityLoading ? 'Memuat...' : 'Muat Ulang'}</span>
                    </button>
                  </div>

                  {/* Stats */}
                  {(() => {
                    const total = mySubmissions.length;
                    const completed = mySubmissions.filter(s => !!s.submitted_at).length;
                    const inProgress = mySubmissions.filter(s => !s.submitted_at).length;
                    const cheated = mySubmissions.filter(s => !!s.is_cheated).length;
                    return (
                      <div className="stats-cards-grid">
                        <div className="stat-card">
                          <div className="stat-icon-box"><svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" /></svg></div>
                          <div className="stat-info-wrap"><span className="stat-label">TOTAL AKTIVITAS</span><span className="stat-value">{total}</span></div>
                        </div>
                        <div className="stat-card">
                          <div className="stat-icon-box" style={{ background: '#dcfce7', color: '#15803d' }}><svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg></div>
                          <div className="stat-info-wrap"><span className="stat-label">SELESAI</span><span className="stat-value">{completed}</span></div>
                        </div>
                        <div className="stat-card">
                          <div className="stat-icon-box" style={{ background: '#fef3c7', color: '#b45309' }}><svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg></div>
                          <div className="stat-info-wrap"><span className="stat-label">SEDANG DIISI</span><span className="stat-value">{inProgress}</span></div>
                        </div>
                        <div className="stat-card" style={{ display: cheated > 0 ? 'flex' : 'none' }}>
                          <div className="stat-icon-box" style={{ background: '#fee2e2', color: '#b91c1c' }}><svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01" /></svg></div>
                          <div className="stat-info-wrap"><span className="stat-label">CURANG</span><span className="stat-value">{cheated}</span></div>
                        </div>
                      </div>
                    );
                  })()}

                  {/* Filters */}
                  <div className="table-card-container">
                    <div className="table-card-header">
                      <h3 className="table-card-title">Riwayat Pengisian</h3>
                      <div className="table-header-filters">
                        <input type="text" className="db-search" placeholder="Cari judul form..." value={activitySearch} onChange={(e) => setActivitySearch(e.target.value)} style={{ width: '220px', padding: '6px 12px', fontSize: '13px' }} />
                        <select className="filter-select" value={activityFilter} onChange={(e) => setActivityFilter(e.target.value)}>
                          <option value="all">Semua Status</option>
                          <option value="completed">Selesai</option>
                          <option value="in_progress">Sedang Diisi</option>
                          <option value="cheated">Curang</option>
                        </select>
                      </div>
                    </div>

                    {activityLoading ? (
                      <div style={{ textAlign: 'center', padding: '48px 0', color: '#64748b' }}>
                        <div className="db-spinner" style={{ margin: '0 auto 12px' }} />
                        <p>Memuat aktivitas...</p>
                      </div>
                    ) : (() => {
                      const filtered = mySubmissions.filter((sub) => {
                        const title = sub.form?.title || '(Form terhapus)';
                        const slug = sub.form?.slug || '';
                        const owner = sub.form?.owner_name || '';
                        const q = activitySearch.toLowerCase();
                        const matchesSearch = !q || title.toLowerCase().includes(q) || slug.toLowerCase().includes(q) || owner.toLowerCase().includes(q);
                        if (!matchesSearch) return false;
                        if (activityFilter === 'completed') return !!sub.submitted_at && !sub.is_cheated;
                        if (activityFilter === 'in_progress') return !sub.submitted_at && !sub.is_cheated;
                        if (activityFilter === 'cheated') return !!sub.is_cheated;
                        return true;
                      });
                      if (filtered.length === 0) {
                        return (
                          <div className="db-empty-state" style={{ padding: '40px 0' }}>
                            <svg width="48" height="48" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                              <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                            </svg>
                            <p>{mySubmissions.length === 0 ? 'Belum ada aktivitas. Coba isi form orang lain via link /f/{slug}' : 'Tidak ada aktivitas yang sesuai filter'}</p>
                          </div>
                        );
                      }
                      return (
                        <>
                          {/* Desktop table */}
                          <div className="resp-table-wrap activity-table-wrap">
                            <table className="resp-data-table">
                              <thead>
                                <tr>
                                  <th>FORM</th>
                                  <th>PEMILIK</th>
                                  <th>MULAI</th>
                                  <th>SUBMIT</th>
                                  <th>PROGRES</th>
                                  <th>STATUS</th>
                                  <th style={{ textAlign: 'right' }}>AKSI</th>
                                </tr>
                              </thead>
                              <tbody>
                                {filtered.map((sub) => {
                                  const isCompleted = !!sub.submitted_at;
                                  const durationStr = (() => {
                                    if (!sub.started_at || !sub.submitted_at) return '-';
                                    const diffMs = parseServerTime(sub.submitted_at).getTime() - parseServerTime(sub.started_at).getTime();
                                    const s = Math.max(0, Math.floor(diffMs / 1000));
                                    const m = Math.floor(s / 60);
                                    const sec = s % 60;
                                    return m > 0 ? `${m}m ${sec}s` : `${sec}s`;
                                  })();
                                  return (
                                    <tr key={sub.id}>
                                      <td>
                                        <div style={{ fontWeight: 700, color: '#0f172a', maxWidth: '220px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }} title={stripHtml(sub.form?.title) || '(Form terhapus)'}>
                                          {stripHtml(sub.form?.title) || <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>(Form terhapus)</span>}
                                        </div>
                                        <div style={{ fontSize: '11px', color: '#94a3b8' }}>
                                          {sub.form?.slug ? `/${sub.form.slug}` : ''} {sub.is_auto_submitted ? '• auto' : ''} {durationStr !== '-' ? `• ${durationStr}` : ''}
                                        </div>
                                      </td>
                                      <td className="td-user-email">{sub.form?.owner_name || '-'}</td>
                                      <td style={{ fontSize: '13px' }}>{formatDateString(sub.started_at)}</td>
                                      <td style={{ fontSize: '13px' }}>{sub.submitted_at ? formatDateString(sub.submitted_at) : <span style={{ color: '#b45309' }}>Belum submit</span>}</td>
                                      <td style={{ fontSize: '13px', fontWeight: 600 }}>{sub.answered_count}/{sub.total_questions}</td>
                                      <td>
                                        {sub.is_cheated ? (
                                          <span className="status-pill cheated">• Curang</span>
                                        ) : isCompleted ? (
                                          <span className="status-pill completed">• Selesai</span>
                                        ) : (
                                          <span className="status-pill process">• Proses</span>
                                        )}
                                      </td>
                                      <td style={{ textAlign: 'right' }}>
                                        <div style={{ display: 'flex', gap: '6px', justifyContent: 'flex-end', flexWrap: 'wrap' }}>
                                          {!isCompleted && sub.form?.slug && (
                                            <button className="btn-table-view" onClick={() => navigate(`/f/${sub.form.slug}`)} title="Lanjutkan mengisi form">
                                              Lanjutkan »
                                            </button>
                                          )}
                                          {isCompleted && sub.form?.allow_see_result && (
                                            <button className="btn-table-view" onClick={() => handleViewMyResult(sub)} disabled={activityResultLoading} style={{ background: '#eff6ff', color: '#0053db' }}>
                                              {activityResultLoading ? '...' : 'Lihat Hasil »'}
                                            </button>
                                          )}
                                          {isCompleted && !sub.form?.allow_see_result && (
                                            <span style={{ fontSize: '11px', color: '#94a3b8' }}>Hasil tertutup</span>
                                          )}
                                        </div>
                                      </td>
                                    </tr>
                                  );
                                })}
                              </tbody>
                            </table>
                          </div>

                          {/* Mobile cards fallback */}
                          <div className="activity-cards-mobile" style={{ display: 'none' }}>
                            {filtered.map((sub) => {
                              const isCompleted = !!sub.submitted_at;
                              return (
                                <div key={sub.id} className="activity-mobile-card">
                                  <div style={{ fontWeight: 700, color: '#0f172a' }}>{stripHtml(sub.form?.title) || '(Form terhapus)'}</div>
                                  <div style={{ fontSize: '12px', color: '#64748b' }}>{sub.form?.owner_name || '-'} • {sub.answered_count}/{sub.total_questions} terjawab</div>
                                  <div style={{ fontSize: '12px', color: '#64748b', marginTop: '4px' }}>Mulai: {formatDateString(sub.started_at)} • Submit: {sub.submitted_at ? formatDateString(sub.submitted_at) : 'Belum'}</div>
                                  <div style={{ marginTop: '8px' }}>
                                    {sub.is_cheated ? <span className="status-pill cheated">Curang</span> : isCompleted ? <span className="status-pill completed">Selesai</span> : <span className="status-pill process">Proses</span>}
                                  </div>
                                </div>
                              );
                            })}
                          </div>

                          <div className="table-card-footer">
                            <span>Menampilkan {filtered.length} dari {mySubmissions.length} aktivitas</span>
                            <span style={{ fontSize: '11px', color: '#94a3b8' }}>ID bukti: potongan UUID submission</span>
                          </div>
                        </>
                      );
                    })()}
                  </div>
                </>
              )}
            </>
          )}
        </section>
      </main>

      {/* Toast */}
      {toast && (
        <div className={`db-toast ${toast.isError ? 'error' : ''}`}>
          {toast.msg}
        </div>
      )}

      {/* Confirm Delete Modal */}
      {confirmDeleteForm && (
        <div className="db-modal-overlay" onClick={() => setConfirmDeleteForm(null)}>
          <div className="db-modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="db-modal-icon danger">
              <svg width="26" height="26" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <polyline points="3 6 5 6 21 6" />
                <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
              </svg>
            </div>
            <h3 className="db-modal-title">Hapus Form</h3>
            <p className="db-modal-text">
              Yakin ingin menghapus form <strong>"{stripHtml(confirmDeleteForm.title)}"</strong>? Semua respons yang masuk ikut terhapus dan tindakan ini tidak bisa dibatalkan.
            </p>
            <div className="db-modal-actions">
              <button className="db-btn-cancel" onClick={() => setConfirmDeleteForm(null)}>
                Batal
              </button>
              <button className="db-btn-danger" onClick={handleConfirmDelete}>
                Hapus
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
