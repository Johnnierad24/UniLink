from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    class Role(models.TextChoices):
        STUDENT = "student", "Student"
        LECTURER = "lecturer", "Lecturer"
        STAFF = "staff", "Staff"
        ADMIN = "admin", "Admin"

    university_id = models.CharField(
        max_length=50, unique=True, null=True, blank=True, help_text="University email/ID for login"
    )
    email = models.EmailField("email address", unique=True, null=True, blank=True)
    email_verified = models.BooleanField(default=False)
    role = models.CharField(max_length=20, choices=Role.choices, default=Role.STUDENT)
    campus = models.ForeignKey(
        "api.Campus", related_name="users", null=True, blank=True, on_delete=models.SET_NULL
    )
    department = models.ForeignKey(
        "api.Department", related_name="users", null=True, blank=True, on_delete=models.SET_NULL
    )
    avatar_url = models.URLField(blank=True)
    notification_prefs = models.JSONField(default=dict, blank=True)

    def __str__(self):
        return f"{self.username} ({self.role})"

# Create your models here.
