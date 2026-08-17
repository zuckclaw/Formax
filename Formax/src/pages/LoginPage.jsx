import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

const LoginPage = () => {
  const navigate = useNavigate()
  const { login } = useAuth()
  const [form, setForm] = useState({ email: '', password: '' })
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
      await login(form)
      navigate('/dashboard')
    } catch (err) {
      setError(err.response?.data?.message || 'Login gagal. Periksa email dan password Anda.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-page">
      <div className="auth-shell">
        <div className="auth-card">
          <div className="auth-tabs" aria-label="Authentication tabs">
            <Link to="/login" className="auth-tab active">
              Login
            </Link>
            <Link to="/register" className="auth-tab">
              Register
            </Link>
          </div>

          <form className="auth-form" onSubmit={handleSubmit}>
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
              {loading ? 'Memproses...' : 'Login'}
            </button>
          </form>

          
        </div>
      </div>
    </div>
  )
}

export default LoginPage
