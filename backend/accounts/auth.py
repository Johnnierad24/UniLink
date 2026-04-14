from django.contrib.auth import get_user_model
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework import serializers
from django.conf import settings

User = get_user_model()


class EmailOrIDTokenSerializer(TokenObtainPairSerializer):
    """
    Accepts login via username OR email OR university_id.
    """

    username_field = User.USERNAME_FIELD  # keep DRF happy, but we override validation

    def validate(self, attrs):
        login = attrs.get("username") or attrs.get("email") or attrs.get("login")
        password = attrs.get("password")
        if not login or not password:
            raise serializers.ValidationError("Login and password are required.")

        user = (
            User.objects.filter(username__iexact=login).first()
            or User.objects.filter(email__iexact=login).first()
            or User.objects.filter(university_id__iexact=login).first()
        )

        if user is None or not user.check_password(password):
            raise serializers.ValidationError("Invalid credentials.")
        if not user.is_active:
            raise serializers.ValidationError("User inactive.")
        if getattr(settings, "REQUIRE_EMAIL_VERIFIED", False) and not user.email_verified:
            raise serializers.ValidationError("Email not verified.")

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
        # accept "login" field for clarity
        if "login" in data and "username" not in data:
            data = data.copy()
            data["username"] = data["login"]
        return super().to_internal_value(data)
