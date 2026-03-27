# IMPORTANT: Copy this file to secrets.py and fill in real values
# secrets.py is gitignored and will NOT be pushed to version control

# Django Secret Key - Generate a new one for production!
# You can generate one with: python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
SECRET_KEY = "dev-secret-key-change-me-in-production"

# Database password
DB_PASSWORD = "postgres"

# Email password (app password for Gmail, or your SMTP provider password)
EMAIL_PASSWORD = ""

# SMS API keys (Africa's Talking or Twilio)
SMS_API_KEY = ""
TWILIO_AUTH_TOKEN = ""
