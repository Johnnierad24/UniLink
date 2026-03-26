from django.contrib import admin
from .models import (
    Campus, Event, Announcement, Resource, Booking, 
    ProcurementRequest, ScheduleEntry, Department, 
    StudentEnrollment, EventGuest, EventPatron
)


@admin.register(Campus)
class CampusAdmin(admin.ModelAdmin):
    list_display = ("name", "location", "created_at")
    search_fields = ("name", "location")


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ("title", "campus", "start_time", "end_time", "is_all_day")
    list_filter = ("campus", "is_all_day", "start_time", "category")
    search_fields = ("title", "description", "location")


@admin.register(Announcement)
class AnnouncementAdmin(admin.ModelAdmin):
    list_display = ("title", "campus", "is_urgent", "published_at")
    list_filter = ("campus", "is_urgent", "published_at")
    search_fields = ("title", "body")


@admin.register(Resource)
class ResourceAdmin(admin.ModelAdmin):
    list_display = ("name", "type", "campus", "capacity", "created_at")
    list_filter = ("type", "campus")
    search_fields = ("name", "location")


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = ("resource", "user", "start_time", "end_time", "status")
    list_filter = ("status", "resource__campus")
    search_fields = ("resource__name", "user__username")


@admin.register(ProcurementRequest)
class ProcurementAdmin(admin.ModelAdmin):
    list_display = ("title", "priority", "status", "requested_by", "estimated_cost", "created_at")
    list_filter = ("priority", "status")
    search_fields = ("title", "description")


@admin.register(ScheduleEntry)
class ScheduleEntryAdmin(admin.ModelAdmin):
    list_display = ("title", "course_code", "campus", "start_time", "end_time", "audience", "is_postponed")
    list_filter = ("campus", "audience", "is_postponed", "department")
    search_fields = ("title", "course_code", "room")


@admin.register(Department)
class DepartmentAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "campus")
    list_filter = ("campus",)
    search_fields = ("name", "code")


@admin.register(StudentEnrollment)
class StudentEnrollmentAdmin(admin.ModelAdmin):
    list_display = ("student", "schedule_entry", "enrolled_at")
    list_filter = ("schedule_entry__campus",)
    search_fields = ("student__username", "schedule_entry__title")


@admin.register(EventGuest)
class EventGuestAdmin(admin.ModelAdmin):
    list_display = ("user", "event", "role", "invited_at")
    list_filter = ("role",)
    search_fields = ("user__username", "event__title")


@admin.register(EventPatron)
class EventPatronAdmin(admin.ModelAdmin):
    list_display = ("user", "event", "role", "invited_at")
    list_filter = ("role",)
    search_fields = ("user__username", "event__title")
