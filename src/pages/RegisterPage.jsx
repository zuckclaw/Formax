import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

const RegisterPage = () => {
  const navigate = useNavigate()
  const { register } = useAuth()
  const [form, setForm] = useState({
    full_name: '',
    email: '',
    password: '',
    password_confirmation: '',
  })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleChange = (event) => {
    const { name, value } = event.target
    setForm((prev) => ({ ...prev, [name]: value }))
  }

  const handleSubmit = async (event) => {
    event.preventDefault()
    setError('')
    setLoading(true)

    try {
      await register(form)
      navigate('/dashboard')
    } catch (err) {
      setError(err.response?.data?.message || 'Registrasi gagal. Silakan coba lagi.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-page">
      <div className="auth-shell">
        <div className="auth-card">
          <div className="auth-tabs" aria-label="Authentication tabs">
            <Link to="/login" className="auth-tab">
              Login
            </Link>
            <Link to="/register" className="auth-tab active">
              Register
            </Link>
          </div>

          <form className="auth-form" onSubmit={handleSubmit}>
            <label>
              <span>Full Name*</span>
              <input
                type="text"
                name="full_name"
                value={form.full_name}
                onChange={handleChange}
                placeholder="Enter your full name"
                required
              />
            </label>

            <label>
              <span>Email Address*</span>
              <input
                type="email"
                name="email"
                value={form.email}
                onChange={handleChange}
                placeholder="Enter your email address"
                required
              />
            </label>

            <label>
              <span>Password*</span>
              <input
                type="password"
                name="password"
                value={form.password}
                onChange={handleChange}
                placeholder="Enter your password"
                required
              />
            </label>

            <label className="auth-checkline">
              <input type="checkbox" />
              <span>Remember me</span>
            </label>

            {error ? <div className="error-box">{error}</div> : null}

            <button type="submit" disabled={loading}>
              {loading ? 'Mendaftar...' : 'Register'}
            </button>
          </form>

          
        </div>
      </div>
    </div>
  )
}

export default RegisterPage
