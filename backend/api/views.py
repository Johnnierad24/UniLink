from rest_framework import viewsets, filters
from django_filters.rest_framework import DjangoFilterBackend
from django.core.mail import send_mail
from django.conf import settings
from .models import Campus, Event, Announcement
from .models import (
    Campus,
    Event,
    Announcement,
    Resource,
    Booking,
    ProcurementRequest,
    ScheduleEntry,
)
from .serializers import (
    CampusSerializer,
    EventSerializer,
    AnnouncementSerializer,
    ResourceSerializer,
    BookingSerializer,
    ProcurementRequestSerializer,
    ProcurementStatusSerializer,
    ScheduleEntrySerializer,
    PostponeClassSerializer,
)
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import status
from .permissions import IsStaffOrReadOnly, IsOwnerOrReadOnly


class CampusViewSet(viewsets.ModelViewSet):
    queryset = Campus.objects.all()
    serializer_class = CampusSerializer


class EventViewSet(viewsets.ModelViewSet):
    queryset = Event.objects.select_related("campus").all()
    serializer_class = EventSerializer
    permission_classes = [IsStaffOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ["campus", "category", "is_all_day"]
    search_fields = ["title", "description", "location"]
    ordering_fields = ["start_time", "end_time", "created_at"]


class AnnouncementViewSet(viewsets.ModelViewSet):
    queryset = Announcement.objects.select_related("campus").all()
    serializer_class = AnnouncementSerializer
    permission_classes = [IsStaffOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ["campus", "is_urgent"]
    search_fields = ["title", "body"]
    ordering_fields = ["published_at"]


class ResourceViewSet(viewsets.ModelViewSet):
    queryset = Resource.objects.select_related("campus").all()
    serializer_class = ResourceSerializer
    permission_classes = [IsStaffOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ["campus", "type"]
    search_fields = ["name", "location"]
    ordering_fields = ["name", "capacity"]


class BookingViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, IsOwnerOrReadOnly]
    serializer_class = BookingSerializer
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ["resource", "status", "resource__campus"]
    ordering_fields = ["start_time", "end_time", "created_at"]

    def get_queryset(self):
        return Booking.objects.select_related("resource", "user").filter(user=self.request.user)


class ProcurementRequestViewSet(viewsets.ModelViewSet):
    serializer_class = ProcurementRequestSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter, filters.SearchFilter]
    filterset_fields = ["priority", "status", "linked_event", "requested_by"]
    ordering_fields = ["created_at", "estimated_cost"]
    search_fields = ["title", "description"]

    def get_queryset(self):
        qs = ProcurementRequest.objects.select_related("requested_by", "linked_event")
        user = self.request.user
        if user.is_anonymous:
            return qs.none()
        if user.role in ["admin", "staff"]:
            return qs
        return qs.filter(requested_by=user)

    def perform_create(self, serializer):
        serializer.save(requested_by=self.request.user)

    @action(detail=True, methods=["patch"], permission_classes=[IsAuthenticated])
    def status(self, request, pk=None):
        if request.user.role not in ["admin", "staff"]:
            return Response(status=status.HTTP_403_FORBIDDEN)
        instance = self.get_object()
        serializer = ProcurementStatusSerializer(instance, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class ScheduleEntryViewSet(viewsets.ModelViewSet):
    queryset = ScheduleEntry.objects.select_related("campus", "lecturer", "department").all()
    serializer_class = ScheduleEntrySerializer
    permission_classes = [IsStaffOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter, filters.SearchFilter]
    filterset_fields = ["campus", "audience", "lecturer", "department"]
    ordering_fields = ["start_time", "end_time"]
    search_fields = ["title", "course_code", "room"]

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if user.is_authenticated:
            if user.role == "lecturer":
                return qs.filter(lecturer=user)
            elif user.role == "student" and user.department:
                return qs.filter(department=user.department)
        return qs

    @action(detail=True, methods=["post"], permission_classes=[IsAuthenticated])
    def postpone(self, request, pk=None):
        from .models import StudentEnrollment
        entry = self.get_object()
        
        if request.user.role != "lecturer":
            return Response(
                {"error": "Only lecturers can postpone classes"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        serializer = PostponeClassSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        reason = serializer.validated_data.get("reason", "No reason provided")
        
        enrolled_students = StudentEnrollment.objects.filter(
            schedule_entry=entry
        ).select_related("student").values_list(
            "student__email", "student__username"
        )
        
        emails = [s[0] for s in enrolled_students if s[0]]
        student_names = [s[1] for s in enrolled_students]
        
        subject = f"Class Postponed: {entry.title} - {entry.course_code}"
        message = f"""
Dear Student,

This is to inform you that your class has been postponed.

Class Details:
- Subject: {entry.title}
- Course Code: {entry.course_code}
- Room: {entry.room}
- Scheduled Time: {entry.start_time.strftime('%A, %B %d, %Y at %H:%M')} - {entry.end_time.strftime('%H:%M')}
- Lecturer: {entry.lecturer.get_full_name() or entry.lecturer.username}

Reason: {reason}

Please check the timetable for the rescheduled date.

Best regards,
UniLink System
"""
        
        sms_message = f"UniLink: Class postponed - {entry.course_code} ({entry.title}) at {entry.room}. Time: {entry.start_time.strftime('%H:%M')}. Reason: {reason}. Check timetable for rescheduled date."
        
        email_sent = False
        sms_sent = False
        
        if emails:
            try:
                send_mail(
                    subject,
                    message,
                    settings.DEFAULT_FROM_EMAIL,
                    emails,
                    fail_silently=False,
                )
                email_sent = True
            except Exception as e:
                print(f"Email error: {e}")
        
        if student_names:
            try:
                self._send_sms(student_names, sms_message)
                sms_sent = True
            except Exception as e:
                print(f"SMS error: {e}")
        
        entry.is_postponed = True
        entry.postponed_reason = reason
        entry.save()
        
        return Response({
            "message": "Class postponed successfully",
            "details": {
                "class": entry.title,
                "course_code": entry.course_code,
                "reason": reason,
                "students_notified": len(student_names),
                "email_sent": email_sent,
                "sms_sent": sms_sent,
            }
        })
    
    def _send_sms(self, recipients, message):
        """
        Send SMS using Africa'@'s Talking or Twilio.
        Configure in settings.py with:
        - SMS_PROVIDER: 'africastalking' or 'twilio'
        - SMS_API_KEY, SMS_SENDER_ID for Africa'@'s Talking
        - TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER for Twilio
        """
        provider = getattr(settings, 'SMS_PROVIDER', None)
        
        if provider == 'africastalking':
            return self._send_via_africastalking(message)
        elif provider == 'twilio':
            return self._send_via_twilio(message)
        else:
            print(f"SMS would be sent to {len(recipients)} recipients: {message}")
            return True
    
    def _send_via_africastalking(self, message):
        import requests
        api_key = getattr(settings, 'SMS_API_KEY', None)
        sender_id = getattr(settings, 'SMS_SENDER_ID', 'UniLink')
        
        if not api_key:
            print("Africa's Talking API key not configured")
            return False
        
        headers = {
            'ApiKey': api_key,
            'Content-Type': 'application/x-www-form-urlencoded',
        }
        payload = {
            'username': 'sandbox',
            'message': message,
            'senderId': sender_id,
        }
        
        response = requests.post(
            'https://api.sandbox.africastalking.com/version1/messaging',
            headers=headers,
            data=payload
        )
        return response.status_code == 201
    
    def _send_via_twilio(self, message):
        from twilio.rest import Client
        account_sid = getattr(settings, 'TWILIO_ACCOUNT_SID', None)
        auth_token = getattr(settings, 'TWILIO_AUTH_TOKEN', None)
        from_number = getattr(settings, 'TWILIO_PHONE_NUMBER', None)
        
        if not all([account_sid, auth_token, from_number]):
            print("Twilio credentials not configured")
            return False
        
        client = Client(account_sid, auth_token)
        to_numbers = getattr(settings, 'SMS_RECIPIENTS', [])
        
        for to in to_numbers:
            client.messages.create(
                body=message,
                from_=from_number,
                to=to
            )
        return True
