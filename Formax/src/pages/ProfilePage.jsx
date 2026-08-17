import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import MainLayout from '../components/MainLayout'
import { useAuth } from '../context/AuthContext'

const ProfilePage = () => {
  const navigate = useNavigate()
  const { user, updateProfile } = useAuth()

  const userName = user?.full_name || user?.name || 'Pengguna'
  const userEmail = user?.email || ''
  const userAvatar = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=120&q=80'
  const initials = userName
    .split(' ')
    .map((part) => part[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase()

  const [form, setForm] = useState({
    username: userName,
  })
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  const handleChange = (event) => {
    const { name, value } = event.target
    setForm((prev) => ({ ...prev, [name]: value }))
  }

  const handleSubmit = async (event) => {
    event.preventDefault()
    setSaving(true)
    setMessage('')
    setError('')

    try {
      await updateProfile({
        full_name: form.username,
        name: form.username,
      })
      setMessage('Profil berhasil diperbarui.')
    } catch {
      setError('Gagal memperbarui profil.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <MainLayout hideSearch={true}>
      <div className="responses-view">
        <div className="responses-header">
          <div className="header-left">
            <button className="back-btn" onClick={() => navigate(-1)} title="Kembali">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <polyline points="15 18 9 12 15 6" />
              </svg>
            </button>
            <div className="header-text">
              <h2 className="responses-title">Profil</h2>
              <p className="responses-subtitle">Kelola informasi akun Anda</p>
            </div>
          </div>
        </div>

        <div className="profile-page">
          <div className="profile-card">
            {userAvatar ? (
              <img src={userAvatar} alt={userName} className="profile-avatar-large" />
            ) : (
              <div className="profile-avatar-large">{initials}</div>
            )}
            <div className="profile-card-info">
              <h3>{userName}</h3>
              <p>{userEmail}</p>
            </div>
          </div>

          <section className="card profile-form-card">
            <form onSubmit={handleSubmit} className="form-panel">
              <label>
                Username
                <input
                  type="text"
                  name="username"
                  value={form.username}
                  onChange={handleChange}
                  placeholder="Masukkan username"
                  required
                />
              </label>

              <label>
                Email
                <input type="email" value={userEmail} disabled />
              </label>

              {message ? <div className="success-box">{message}</div> : null}
              {error ? <div className="error-box">{error}</div> : null}

              <div className="form-actions">
                <button type="submit" className="primary-btn" disabled={saving}>
                  {saving ? 'Menyimpan...' : 'Simpan Perubahan'}
                </button>
              </div>
            </form>
          </section>
        </div>
      </div>
    </MainLayout>
  )
}

export default ProfilePage
