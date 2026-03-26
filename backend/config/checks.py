from django.core.checks import register, Error
from django.conf import settings


@register()
def security_env_checks(app_configs, **kwargs):
    errors = []
    if getattr(settings, "TESTING", False):
        return errors
    if not settings.DEBUG:
        if settings.SECRET_KEY == "dev-secret-key-change-me":
            errors.append(Error("Set DJANGO_SECRET_KEY for production.", id="config.E001"))
        if settings.ALLOWED_HOSTS in (["localhost"], ["127.0.0.1"]):
            errors.append(Error("Set DJANGO_ALLOWED_HOSTS for production.", id="config.E002"))
        engine = settings.DATABASES["default"]["ENGINE"]
        if engine == "django.db.backends.sqlite3":
            errors.append(Error("Use Postgres in production.", id="config.E003"))
    return errors
