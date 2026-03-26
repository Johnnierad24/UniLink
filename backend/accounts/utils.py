from django.core import signing
from django.conf import settings
from django.core.mail import send_mail
from urllib.parse import urlencode

SIGNER = signing.TimestampSigner(salt="email-verify")


def make_verification_token(user_id: int) -> str:
    return SIGNER.sign(user_id)


def verify_token(token: str, max_age_hours: int = 48) -> int:
    user_id = SIGNER.unsign(token, max_age=max_age_hours * 3600)
    return int(user_id)


def send_verification_email(user):
    if not user.email:
        return False
    token = make_verification_token(user.id)
    link = f"{settings.EMAIL_VERIFICATION_URL}?{urlencode({'token': token})}"
    subject = "Verify your UniLink email"
    body = f"Hi {user.get_full_name() or user.username},\n\nPlease verify your email by visiting:\n{link}\n\nIf you did not request this, ignore this message."
    send_mail(subject, body, settings.DEFAULT_FROM_EMAIL, [user.email], fail_silently=False)
    return True
