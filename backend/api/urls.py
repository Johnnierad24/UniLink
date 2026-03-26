from rest_framework.routers import DefaultRouter
from django.urls import path, include
from .views import (
    CampusViewSet,
    EventViewSet,
    AnnouncementViewSet,
    ResourceViewSet,
    BookingViewSet,
    ProcurementRequestViewSet,
    ScheduleEntryViewSet,
)

router = DefaultRouter()
router.register(r"campuses", CampusViewSet, basename="campus")
router.register(r"events", EventViewSet, basename="event")
router.register(r"announcements", AnnouncementViewSet, basename="announcement")
router.register(r"resources", ResourceViewSet, basename="resource")
router.register(r"bookings", BookingViewSet, basename="booking")
router.register(r"procurements", ProcurementRequestViewSet, basename="procurement")
router.register(r"schedule", ScheduleEntryViewSet, basename="schedule")

urlpatterns = [
    path("", include(router.urls)),
]
