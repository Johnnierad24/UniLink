# IMPORTANT: Copy this file to secrets.py and fill in real values
# secrets.py is gitignored and will NOT be pushed to version control
#
# For production, use environment variables instead of editing this file:
#   export DJANGO_SECRET_KEY=$(python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
#   export DB_PASSWORD="your-secure-db-password"
#   export DJANGO_EMAIL_PASSWORD="your-email-app-password"
#   export SMS_API_KEY="your-sms-api-key"
#   export TWILIO_AUTH_TOKEN="your-twilio-auth-token"

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
from dotenv import load_dotenv

load_dotenv()

# Django Secret Key - MUST be set via environment variable in production!
SECRET_KEY = os.getenv("DJANGO_SECRET_KEY", "")
if not SECRET_KEY:
    raise ValueError("DJANGO_SECRET_KEY environment variable must be set!")

# Database password - MUST be set via environment variable in production!
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
if not DB_PASSWORD and not os.getenv("POSTGRES_URL"):
    raise ValueError("DB_PASSWORD or POSTGRES_URL environment variable must be set!")

# Email password (app password for Gmail, or your SMTP provider password)
EMAIL_PASSWORD = os.getenv("DJANGO_EMAIL_PASSWORD", "")

# SMS API keys (Africa's Talking or Twilio)
SMS_API_KEY = os.getenv("SMS_API_KEY", "")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
