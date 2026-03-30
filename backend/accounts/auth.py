from django.contrib.auth import get_user_model
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework import serializers
from django.conf import settings
from django.core.cache import cache
import hashlib

User = get_user_model()

MAX_FAILED_ATTEMPTS = 5
LOCKOUT_DURATION = 300  # 5 minutes in seconds


def get_user_hash(login):
    """Create a hash for the login to use as cache key"""
    return hashlib.md5(login.lower().encode()).hexdigest()


class EmailOrIDTokenSerializer(TokenObtainPairSerializer):
    """
    Accepts login via username OR email OR university_id.
    Includes rate limiting and account lockout protection.
    """

    username_field = User.USERNAME_FIELD

    def validate(self, attrs):
        login = attrs.get("username") or attrs.get("email") or attrs.get("login")
        password = attrs.get("password")
        
        if not login or not password:
            raise serializers.ValidationError("Login and password are required.")

        # Check if account is locked out
        cache_key = f"login_lockout_{get_user_hash(login)}"
        lockout_count = cache.get(cache_key, 0)
        
        if lockout_count >= MAX_FAILED_ATTEMPTS:
            raise serializers.ValidationError(
                f"Account temporarily locked due to too many failed attempts. Try again in {LOCKOUT_DURATION // 60} minutes."
            )

        user = (
            User.objects.filter(username__iexact=login).first()
            or User.objects.filter(email__iexact=login).first()
            or User.objects.filter(university_id__iexact=login).first()
        )

        if user is None or not user.check_password(password):
            # Increment failed attempt counter
            new_count = lockout_count + 1
            cache.set(cache_key, new_count, LOCKOUT_DURATION)
            
            remaining = MAX_FAILED_ATTEMPTS - new_count
            if remaining > 0:
                raise serializers.ValidationError(
                    f"Invalid credentials. {remaining} attempts remaining before lockout."
                )
            else:
                raise serializers.ValidationError(
                    f"Account temporarily locked due to too many failed attempts. Try again in {LOCKOUT_DURATION // 60} minutes."
                )
        
        if not user.is_active:
            raise serializers.ValidationError("User inactive.")
        
        if getattr(settings, "REQUIRE_EMAIL_VERIFIED", False) and not user.email_verified:
            raise serializers.ValidationError("Email not verified.")

        # Clear failed attempts on successful login
        cache.delete(cache_key)

        data = super().validate({"username": user.username, "password": password})
        data["user"] = {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "role": user.role,
            "campus_id": user.campus_id,
            "department_id": user.department_id,
        }
        return data

    def to_internal_value(self, data):
        if "login" in data and "username" not in data:
            data = data.copy()
            data["username"] = data["login"]
        return super().to_internal_value(data)
