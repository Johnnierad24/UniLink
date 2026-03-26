from django.db import models


class Campus(models.Model):
    name = models.CharField(max_length=120, unique=True)
    location = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self) -> str:
        return self.name


class Event(models.Model):
    class Category(models.TextChoices):
        ACADEMIC = "academic", "Academic"
        SOCIAL = "social", "Social"
        SPORTS = "sports", "Sports"
        ADMIN = "admin", "Administration"
        OTHER = "other", "Other"

    campus = models.ForeignKey(Campus, related_name="events", on_delete=models.CASCADE)
    title = models.CharField(max_length=180)
    description = models.TextField(blank=True)
    location = models.CharField(max_length=255, blank=True)
    category = models.CharField(max_length=40, choices=Category.choices, default=Category.OTHER)
    start_time = models.DateTimeField()
    end_time = models.DateTimeField(null=True, blank=True)
    is_all_day = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-start_time"]

    def __str__(self) -> str:
        return f"{self.title} @ {self.campus}"


class Announcement(models.Model):
    campus = models.ForeignKey(
        Campus, related_name="announcements", on_delete=models.SET_NULL, null=True, blank=True
    )
    title = models.CharField(max_length=180)
    body = models.TextField()
    is_urgent = models.BooleanField(default=False)
    published_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-published_at"]

    def __str__(self) -> str:
        return self.title


class Resource(models.Model):
    class Type(models.TextChoices):
        LABORATORY = "laboratory", "Laboratory"
        STUDY_ROOM = "study_room", "Study Room"
        LECTURE_HALL = "lecture_hall", "Lecture Hall"
        COLLAB_ZONE = "collab_zone", "Collaboration Zone"

    campus = models.ForeignKey(Campus, related_name="resources", on_delete=models.CASCADE)
    name = models.CharField(max_length=120)
    type = models.CharField(max_length=40, choices=Type.choices)
    location = models.CharField(max_length=255, blank=True)
    capacity = models.PositiveIntegerField(default=1)
    amenities = models.JSONField(default=list, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("campus", "name")
        ordering = ["campus", "name"]

    def __str__(self) -> str:
        return f"{self.name} ({self.get_type_display()})"


class Booking(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        CONFIRMED = "confirmed", "Confirmed"
        CANCELLED = "cancelled", "Cancelled"

    resource = models.ForeignKey(Resource, related_name="bookings", on_delete=models.CASCADE)
    user = models.ForeignKey("accounts.User", related_name="bookings", on_delete=models.CASCADE)
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    attendees = models.PositiveIntegerField(default=1)
    notes = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-start_time"]
        indexes = [
            models.Index(fields=["resource", "start_time", "end_time"]),
        ]

    def __str__(self) -> str:
        return f"{self.resource} {self.start_time} - {self.end_time}"


class ProcurementRequest(models.Model):
    class Priority(models.TextChoices):
        STANDARD = "standard", "Standard"
        URGENT = "urgent", "Urgent"
        CRITICAL = "critical", "Critical"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    title = models.CharField(max_length=180)
    description = models.TextField(blank=True)
    estimated_cost = models.DecimalField(max_digits=12, decimal_places=2)
    priority = models.CharField(max_length=20, choices=Priority.choices, default=Priority.STANDARD)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    requested_by = models.ForeignKey("accounts.User", related_name="procurements", on_delete=models.CASCADE)
    linked_event = models.ForeignKey(Event, related_name="procurements", on_delete=models.SET_NULL, null=True, blank=True)
    reason = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return self.title


class ScheduleEntry(models.Model):
    class Audience(models.TextChoices):
        STUDENT = "student", "Student"
        LECTURER = "lecturer", "Lecturer"
        STAFF = "staff", "Staff"
        ALL = "all", "All"

    campus = models.ForeignKey(Campus, related_name="schedule_entries", on_delete=models.CASCADE)
    title = models.CharField(max_length=180)
    course_code = models.CharField(max_length=40, blank=True)
    room = models.CharField(max_length=120, blank=True)
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    enrollment_count = models.PositiveIntegerField(default=0)
    lecturer = models.ForeignKey("accounts.User", related_name="schedule_entries", null=True, blank=True, on_delete=models.SET_NULL)
    audience = models.CharField(max_length=20, choices=Audience.choices, default=Audience.ALL)
    department = models.ForeignKey("Department", related_name="schedule_entries", null=True, blank=True, on_delete=models.SET_NULL)
    is_postponed = models.BooleanField(default=False)
    postponed_reason = models.TextField(blank=True)
    postponed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["start_time"]

    def __str__(self) -> str:
        return f"{self.title} ({self.course_code})"


class Department(models.Model):
    name = models.CharField(max_length=180)
    code = models.CharField(max_length=20, unique=True)
    campus = models.ForeignKey(Campus, related_name="departments", on_delete=models.CASCADE)

    class Meta:
        ordering = ["name"]

    def __str__(self) -> str:
        return f"{self.name} ({self.code})"


class StudentEnrollment(models.Model):
    student = models.ForeignKey("accounts.User", related_name="enrollments", on_delete=models.CASCADE)
    schedule_entry = models.ForeignKey(ScheduleEntry, related_name="enrollments", on_delete=models.CASCADE)
    enrolled_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("student", "schedule_entry")

    def __str__(self) -> str:
        return f"{self.student.username} - {self.schedule_entry}"


class EventGuest(models.Model):
    event = models.ForeignKey(Event, related_name="event_guests", on_delete=models.CASCADE)
    user = models.ForeignKey("accounts.User", related_name="guest_events", on_delete=models.CASCADE)
    role = models.CharField(max_length=50, default="guest")
    invited_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("event", "user")

    def __str__(self) -> str:
        return f"{self.user.username} - {self.event.title} ({self.role})"


class EventPatron(models.Model):
    event = models.ForeignKey(Event, related_name="event_patrons", on_delete=models.CASCADE)
    user = models.ForeignKey("accounts.User", related_name="patron_events", on_delete=models.CASCADE)
    role = models.CharField(max_length=50, default="patron")
    invited_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("event", "user")

    def __str__(self) -> str:
        return f"{self.user.username} - {self.event.title} ({self.role})"
