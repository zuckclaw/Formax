import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.utils import formatdate, make_msgid
from dotenv import load_dotenv

load_dotenv()

SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SENDER_EMAIL = os.getenv("SENDER_EMAIL", "formax.support@gmail.com")
APP_PASSWORD = (os.getenv("APP_PASSWORD") or "").strip()


def send_otp_email(recipient_email: str, otp_code: str, purpose: str = "Verifikasi"):
    sender_email = os.getenv("SENDER_EMAIL", SENDER_EMAIL)
    msg = MIMEMultipart("alternative")
    msg["From"] = f"Form4x <{sender_email}>"
    msg["To"] = recipient_email
    is_reset = "reset" in purpose.lower()
    msg["Subject"] = "[Form4x] Kode reset password Anda" if is_reset else "[Form4x] Kode verifikasi Anda"
    msg["Reply-To"] = sender_email
    msg["Auto-Submitted"] = "auto-generated"
    msg["X-Auto-Response-Suppress"] = "All"
    try:
        domain = sender_email.split("@")[-1] if "@" in sender_email else None
        msg["Message-ID"] = make_msgid(domain=domain)
    except Exception:
        pass
    msg["Date"] = formatdate(localtime=True)

    text_body = f"""
Halo,

Kode verifikasi Form4x Anda:

{otp_code}

Kode berlaku 5 menit. Jika Anda tidak meminta kode ini, abaikan email ini.

Form4x
""".strip()

    html_body = f"""
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kode Verifikasi Form4x</title>
</head>
<body style="margin:0;padding:0;background-color:#f8fafc;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;color:#1e293b;">
  <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color:#f8fafc;padding:24px 16px;">
    <tr>
      <td align="center">
        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width:480px;background-color:#ffffff;border-radius:12px;border:1px solid #e2e8f0;">
          <tr>
            <td style="padding:32px 28px 24px 28px;">
              <p style="margin:0 0 8px 0;font-size:18px;font-weight:700;color:#0f172a;">Kode verifikasi Anda</p>
              <p style="margin:0 0 20px 0;font-size:14px;line-height:1.6;color:#475569;">Gunakan kode di bawah ini untuk melanjutkan. Kode berlaku 5 menit.</p>
              <p style="margin:0 0 20px 0;font-family:'Courier New',Consolas,Monaco,monospace;font-size:32px;font-weight:800;letter-spacing:8px;color:#1d4ed8;text-align:center;">{otp_code}</p>
              <p style="margin:0;font-size:12px;line-height:1.6;color:#64748b;">Jika Anda tidak meminta kode ini, abaikan email ini. Jangan bagikan kode kepada siapapun.</p>
            </td>
          </tr>
          <tr>
            <td style="background-color:#f8fafc;border-top:1px solid #f1f5f9;padding:16px 28px;text-align:center;">
              <p style="margin:0;font-size:11px;color:#94a3b8;">Email otomatis dari Form4x. Anda menerima ini karena meminta kode verifikasi.</p>
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
