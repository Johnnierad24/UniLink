from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    class Role(models.TextChoices):
        STUDENT = "student", "Student"
        LECTURER = "lecturer", "Lecturer"
        DIRECTOR = "director", "Director"
        COORDINATOR = "coordinator", "Coordinator"
        PROCUREMENT = "procurement", "Procurement Officer"
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

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        
        # Generate unique university ID if not set
        if is_new and not self.university_id:
            import uuid
            # Generate a unique university ID based on role and uuid
            role_prefix = self.role[:3].upper() if self.role else "USR"
            unique_suffix = str(uuid.uuid4().int)[:8]
            self.university_id = f"{role_prefix}{unique_suffix}"
        
        super().save(*args, **kwargs)
        
        # Set default campus based on role for new users
        if is_new and self.campus is None:
            from api.models import Campus
            try:
                if self.role == self.Role.PROCUREMENT:
                    # Set campus to Main Campus (id=1) for procurement officers
                    main_campus = Campus.objects.filter(name__icontains="Main").first()
                    if main_campus:
                        self.campus = main_campus
                        super().save(update_fields=['campus'])
                elif self.role == self.Role.ADMIN:
                    # Set campus to Town Campus (id=2) for admins
                    town_campus = Campus.objects.filter(name__icontains="Town").first()
                    if town_campus:
                        self.campus = town_campus
                        super().save(update_fields=['campus'])
            except Exception:
                pass  # Avoid import issues during migrations

    @property
    def can_manage_content(self) -> bool:
        return self.role in {
            self.Role.STAFF,
            self.Role.ADMIN,
            self.Role.DIRECTOR,
            self.Role.COORDINATOR,
        }

    @property
    def can_view_procurement(self) -> bool:
        return self.role in {
            self.Role.PROCUREMENT,
            self.Role.DIRECTOR,
            self.Role.COORDINATOR,
            self.Role.STAFF,
            self.Role.ADMIN,
        }

    @property
    def can_approve_procurement(self) -> bool:
        return self.role in {
            self.Role.PROCUREMENT,
            self.Role.STAFF,
            self.Role.ADMIN,
        }

# Create your models here.
