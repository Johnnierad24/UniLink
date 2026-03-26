from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from .models import User


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    fieldsets = DjangoUserAdmin.fieldsets + (
        ("UniLink", {"fields": ("role", "campus", "department", "university_id", "avatar_url", "notification_prefs")}),
    )
    list_display = ("username", "email", "university_id", "role", "campus", "department", "is_staff")
    list_filter = ("role", "campus", "department", "is_staff")
