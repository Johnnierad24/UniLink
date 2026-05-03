from rest_framework import serializers

from accounts.models import User

from .models import (
    Announcement,
    Booking,
    Campus,
    Event,
    ProcurementRequest,
    Resource,
    ScheduleEntry,
    StudentEnrollment,
)


class UserSummarySerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "username", "email", "role"]


class EventBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = Event
        fields = ["id", "title"]


class ResourceBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = Resource
        fields = ["id", "name", "type", "location", "capacity"]


class CampusSerializer(serializers.ModelSerializer):
    class Meta:
        model = Campus
        fields = ["id", "name", "location", "created_at"]


class EventSerializer(serializers.ModelSerializer):
    campus = CampusSerializer(read_only=True)
    campus_id = serializers.PrimaryKeyRelatedField(
        queryset=Campus.objects.all(), source="campus", write_only=True
    )
    guests = serializers.SerializerMethodField()
    patrons = serializers.SerializerMethodField()

    class Meta:
        model = Event
        fields = [
            "id",
            "title",
            "description",
            "location",
            "category",
            "start_time",
            "end_time",
            "is_all_day",
            "campus",
            "campus_id",
            "created_at",
            "guests",
            "patrons",
        ]

    def get_guests(self, obj):
        from accounts.serializers import UserBriefSerializer
        return UserBriefSerializer([g.user for g in obj.event_guests.all()], many=True).data

    def get_patrons(self, obj):
        from accounts.serializers import UserBriefSerializer
        return UserBriefSerializer([p.user for p in obj.event_patrons.all()], many=True).data


class AnnouncementSerializer(serializers.ModelSerializer):
    campus = CampusSerializer(read_only=True)
    campus_id = serializers.PrimaryKeyRelatedField(
        queryset=Campus.objects.all(), source="campus", write_only=True, allow_null=True, required=False
    )

    class Meta:
        model = Announcement
        fields = [
            "id",
            "title",
            "body",
            "is_urgent",
            "published_at",
            "campus",
            "campus_id",
        ]


class ResourceSerializer(serializers.ModelSerializer):
    campus = CampusSerializer(read_only=True)
    campus_id = serializers.PrimaryKeyRelatedField(
        queryset=Campus.objects.all(), source="campus", write_only=True
    )

    class Meta:
        model = Resource
        fields = [
            "id",
            "name",
            "type",
            "location",
            "capacity",
            "amenities",
            "campus",
            "campus_id",
            "created_at",
        ]


class BookingSerializer(serializers.ModelSerializer):
    resource = serializers.PrimaryKeyRelatedField(queryset=Resource.objects.all())
    user = serializers.HiddenField(default=serializers.CurrentUserDefault())

    class Meta:
        model = Booking
        fields = [
            "id",
            "resource",
            "user",
            "start_time",
            "end_time",
            "attendees",
            "notes",
            "status",
            "created_at",
        ]
        read_only_fields = ["created_at"]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["resource"] = ResourceBriefSerializer(instance.resource).data
        data["user"] = UserSummarySerializer(instance.user).data
        return data

    def validate_status(self, value):
        if not self.instance:
            return value
        if value != Booking.Status.CANCELLED:
            raise serializers.ValidationError("Only cancellation is supported through this endpoint.")
        return value

    def validate(self, attrs):
        start = attrs.get("start_time")
        end = attrs.get("end_time")
        resource = attrs.get("resource") or getattr(self.instance, "resource", None)
        if start and end and end <= start:
            raise serializers.ValidationError("end_time must be after start_time")
        if resource and start and end:
            overlaps = Booking.objects.filter(
                resource=resource,
                status__in=[Booking.Status.PENDING, Booking.Status.CONFIRMED],
                start_time__lt=end,
                end_time__gt=start,
            )
            if self.instance:
                overlaps = overlaps.exclude(pk=self.instance.pk)
            if overlaps.exists():
                raise serializers.ValidationError("Booking overlaps with an existing reservation.")
        return attrs


class ProcurementRequestSerializer(serializers.ModelSerializer):
    requested_by = serializers.HiddenField(default=serializers.CurrentUserDefault())
    linked_event = serializers.PrimaryKeyRelatedField(
        queryset=Event.objects.all(), allow_null=True, required=False
    )
    approved_by = serializers.SerializerMethodField()

    class Meta:
        model = ProcurementRequest
        fields = [
            "id",
            "title",
            "description",
            "estimated_cost",
            "priority",
            "status",
            "requested_by",
            "linked_event",
            "reason",
            "approved_by",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["status", "approved_by", "created_at", "updated_at"]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["requested_by"] = UserSummarySerializer(instance.requested_by).data
        data["linked_event"] = (
            EventBriefSerializer(instance.linked_event).data if instance.linked_event else None
        )
        return data

    def get_approved_by(self, obj):
        if obj.approved_by:
            return UserSummarySerializer(obj.approved_by).data
        return None


class ProcurementStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProcurementRequest
        fields = ["status", "reason"]


class ScheduleEntrySerializer(serializers.ModelSerializer):
    lecturer = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(), allow_null=True, required=False
    )
    campus = CampusSerializer(read_only=True)
    campus_id = serializers.PrimaryKeyRelatedField(
        queryset=Campus.objects.all(), source="campus", write_only=True
    )
    department = serializers.SerializerMethodField()

    class Meta:
        model = ScheduleEntry
        fields = [
            "id",
            "title",
            "course_code",
            "room",
            "start_time",
            "end_time",
            "enrollment_count",
            "lecturer",
            "audience",
            "campus",
            "campus_id",
            "department",
            "is_postponed",
            "postponed_reason",
            "created_at",
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["lecturer"] = (
            UserSummarySerializer(instance.lecturer).data if instance.lecturer else None
        )
        return data

    def get_department(self, obj):
        if hasattr(obj, 'department') and obj.department:
            return {"id": obj.department.id, "name": obj.department.name}
        return None

    def validate(self, attrs):
        """Limit lecturers to 2 units per day (except Sunday)"""
        lecturer = attrs.get('lecturer') or (self.instance.lecturer if self.instance else None)
        start_time = attrs.get('start_time') or (self.instance.start_time if self.instance else None)
        
        if lecturer and start_time:
            # Check if lecturer is a lecturer role
            if hasattr(lecturer, 'role') and lecturer.role == User.Role.LECTURER:
                # Sunday (weekday 6 in Python) has no limit
                if start_time.weekday() != 6:  # Not Sunday
                    # Count existing schedule entries for this lecturer on the same day
                    from django.db.models import Q
                    from datetime import datetime, time
                    
                    # Get start of day and end of day
                    day_start = datetime.combine(start_time.date(), time.min)
                    day_end = datetime.combine(start_time.date(), time.max)
                    
                    # Count entries for this lecturer on this day
                    existing_count = ScheduleEntry.objects.filter(
                        lecturer=lecturer,
                        start_time__date=start_time.date()
                    )
                    # Exclude current instance if updating
                    if self.instance:
                        existing_count = existing_count.exclude(pk=self.instance.pk)
                    
                    if existing_count.count() >= 2:
                        raise serializers.ValidationError(
                            "Lecturers are limited to 2 units per day (except Sunday)."
                        )
        
        return attrs


class PostponeClassSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, max_length=500)
