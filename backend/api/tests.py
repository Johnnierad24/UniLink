from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIClient
from accounts.models import User
from django.conf import settings
from django.test.utils import override_settings
from django.core import mail
from .models import Campus, Resource, Booking, ProcurementRequest, ScheduleEntry
from rest_framework import status


class BookingOverlapTest(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username="u1", email="u1@example.com", password="pass")
        self.client.force_authenticate(self.user)
        self.campus = Campus.objects.create(name="Main", location="Nairobi")
        self.resource = Resource.objects.create(campus=self.campus, name="Pod", type="study_room", capacity=4)

    def test_prevent_overlap(self):
        start = timezone.now()
        end = start + timezone.timedelta(hours=1)
        Booking.objects.create(resource=self.resource, user=self.user, start_time=start, end_time=end)
        resp = self.client.post(
            reverse("booking-list"),
            {
                "resource": self.resource.id,
                "start_time": start.isoformat(),
                "end_time": (end - timezone.timedelta(minutes=30)).isoformat(),
                "attendees": 2,
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 400)


class AuthLoginTest(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username="user1", email="user1@example.com", password="pass123", university_id="CT201/0001/24"
        )

    def test_login_by_email(self):
        resp = self.client.post(reverse("token_obtain_email_or_id"), {"login": "user1@example.com", "password": "pass123"})
        self.assertEqual(resp.status_code, 200)

    def test_login_by_university_id(self):
        resp = self.client.post(reverse("token_obtain_email_or_id"), {"login": "CT201/0001/24", "password": "pass123"})
        self.assertEqual(resp.status_code, 200)

    @override_settings(REQUIRE_EMAIL_VERIFIED=True)
    def test_login_blocked_until_verified(self):
        resp = self.client.post(reverse("token_obtain_email_or_id"), {"login": "user1@example.com", "password": "pass123"})
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        # simulate verification
        self.user.email_verified = True
        self.user.save()
        resp = self.client.post(reverse("token_obtain_email_or_id"), {"login": "user1@example.com", "password": "pass123"})
        self.assertEqual(resp.status_code, 200)

    @override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
    def test_verification_email_sent(self):
        self.client.force_authenticate(self.user)
        resp = self.client.post(reverse("verify_request"))
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(len(mail.outbox), 1)


class PermissionTest(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.staff = User.objects.create_user(username="staff", email="s@example.com", password="pass", role="staff", is_staff=True)
        self.user = User.objects.create_user(username="user", email="u@example.com", password="pass")
        self.campus = Campus.objects.create(name="Main", location="Nairobi")

    def test_event_create_requires_staff(self):
        url = reverse("event-list")
        data = {
            "campus_id": self.campus.id,
            "title": "Test",
            "description": "",
            "location": "",
            "category": "academic",
            "start_time": "2026-04-10T09:00:00Z",
            "end_time": "2026-04-10T10:00:00Z",
            "is_all_day": False,
        }
        self.client.force_authenticate(self.user)
        resp = self.client.post(url, data, format="json")
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)
        self.client.force_authenticate(self.staff)
        resp = self.client.post(url, data, format="json")
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)


class ProcurementTransitionTest(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.staff = User.objects.create_user(username="staff", email="s2@example.com", password="pass", role="staff", is_staff=True)
        self.user = User.objects.create_user(username="user2", email="u2@example.com", password="pass")
        self.client.force_authenticate(self.user)
        self.pr = ProcurementRequest.objects.create(
            title="Microscopes", description="", estimated_cost=1000, priority="urgent", requested_by=self.user
        )

    def test_only_staff_can_change_status(self):
        url = reverse("procurement-status", args=[self.pr.id])
        resp = self.client.patch(url, {"status": "approved"}, format="json")
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)
        self.client.force_authenticate(self.staff)
        resp = self.client.patch(url, {"status": "approved"}, format="json")
        self.assertEqual(resp.status_code, status.HTTP_200_OK)


class ScheduleCrudTest(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.staff = User.objects.create_user(username="staff3", email="s3@example.com", password="pass", role="staff", is_staff=True)
        self.user = User.objects.create_user(username="user3", email="u3@example.com", password="pass")
        self.campus = Campus.objects.create(name="Main", location="Nairobi")

    def test_schedule_requires_staff(self):
        url = reverse("schedule-list")
        data = {
            "campus": self.campus.id,
            "title": "Algorithms",
            "course_code": "CS-101",
            "room": "101",
            "start_time": "2026-04-10T09:00:00Z",
            "end_time": "2026-04-10T10:00:00Z",
            "enrollment_count": 30,
            "audience": "student",
        }
        self.client.force_authenticate(self.user)
        resp = self.client.post(url, data, format="json")
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)
        self.client.force_authenticate(self.staff)
        resp = self.client.post(url, data, format="json")
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
