import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv

load_dotenv()

SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SENDER_EMAIL = os.getenv("SENDER_EMAIL", "formax.support@gmail.com")
APP_PASSWORD = (os.getenv("APP_PASSWORD") or "").strip()


def send_otp_email(recipient_email: str, otp_code: str, purpose: str = "Verifikasi"):
    sender_email = os.getenv("SENDER_EMAIL", SENDER_EMAIL)
    msg = MIMEMultipart("alternative")
    msg["From"] = f"Form4x Support <{sender_email}>"
    msg["To"] = recipient_email
    msg["Subject"] = f"{otp_code} - {purpose} Form4x"

    # Plain text version for fallback
    text_body = f"""
Halo,

Berikut adalah kode verifikasi (OTP) untuk akun Form4x Anda:

========================
    {otp_code}
========================

Kode ini berlaku selama 5 menit.
Demi keamanan akun Anda, jangan bagikan kode ini kepada siapapun.

Salam,
Tim Form4x
    """.strip()

    # Premium Professional HTML email version
    html_body = f"""
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kode Verifikasi Form4x</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f4f7fc; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #1e293b;">
  <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f4f7fc; padding: 40px 16px;">
    <tr>
      <td align="center">
        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 540px; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08); border: 1px solid #e2e8f0;">
          
          <!-- Header Banner -->
          <tr>
            <td style="background: linear-gradient(135deg, #1e40af 0%, #3b82f6 100%); padding: 36px 32px; text-align: center;">
              <table border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="center">
                    <!-- Logo / Brand Text -->
                    <span style="font-size: 28px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px; text-shadow: 0 2px 4px rgba(0,0,0,0.15);">Form4x</span>
                    <p style="margin: 6px 0 0 0; font-size: 13px; color: #dbeafe; font-weight: 400; opacity: 0.95;">Platform Formulir & Ujian Online Terlengkap</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Body Content -->
          <tr>
            <td style="padding: 36px 32px 28px 32px;">
              <h2 style="margin: 0 0 12px 0; font-size: 20px; font-weight: 700; color: #0f172a;">Halo,</h2>
              <p style="margin: 0 0 24px 0; font-size: 14px; line-height: 1.6; color: #475569;">
                Gunakan kode verifikasi (OTP) di bawah ini untuk melanjutkan verifikasi akun <strong>Form4x</strong> Anda.
              </p>

              <!-- OTP Code Display Card -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin-bottom: 24px;">
                <tr>
                  <td align="center" style="background-color: #f0f6ff; border: 2px dashed #3b82f6; border-radius: 12px; padding: 24px 16px;">
                    <span style="display: block; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.5px; color: #2563eb; margin-bottom: 8px;">KODE VERIFIKASI (OTP)</span>
                    <span style="display: inline-block; font-family: 'Courier New', Consolas, Monaco, monospace; font-size: 36px; font-weight: 800; letter-spacing: 10px; color: #1d4ed8; text-indent: 10px;">{otp_code}</span>
                  </td>
                </tr>
              </table>

              <!-- Expiry Alert -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin-bottom: 20px; background-color: #fffbeb; border: 1px solid #fde68a; border-radius: 10px; padding: 12px 16px;">
                <tr>
                  <td style="font-size: 13px; color: #b45309; line-height: 1.5;">
                    <strong>Penting:</strong> Kode ini hanya berlaku selama <strong>5 menit</strong>.
                  </td>
                </tr>
              </table>

              <!-- Security Notice -->
              <p style="margin: 0 0 20px 0; font-size: 13px; line-height: 1.6; color: #64748b;">
                <strong>Keamanan:</strong> Jaga kerahasiaan kode ini. Tim Form4x tidak pernah meminta kode verifikasi Anda.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f8fafc; border-top: 1px solid #f1f5f9; padding: 20px 32px; text-align: center;">
              <p style="margin: 0 0 6px 0; font-size: 12px; color: #94a3b8;">
                Email ini dikirim secara otomatis. Mohon tidak membalas email ini.
              </p>
              <p style="margin: 0; font-size: 12px; font-weight: 600; color: #64748b;">
                &copy; Form4x. All rights reserved.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    """.strip()

    msg.attach(MIMEText(text_body, "plain", "utf-8"))
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    try:
        import ssl

        app_password = (os.getenv("APP_PASSWORD") or APP_PASSWORD).strip()
        smtp_server = os.getenv("SMTP_SERVER", SMTP_SERVER)
        smtp_port = int(os.getenv("SMTP_PORT", SMTP_PORT))

        if not app_password:
            print("Failed to send email: APP_PASSWORD belum dikonfigurasi (isi di .env)")
            return False
        context = ssl.create_default_context()
        server = smtplib.SMTP(smtp_server, smtp_port, timeout=10)
        server.starttls(context=context)
        server.login(sender_email, app_password)
        server.send_message(msg)
        server.quit()
        return True
    except Exception as e:
        print(f"Failed to send email: {e}")
        return False
