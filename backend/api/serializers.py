from rest_framework import serializers
from .models import Campus, Event, Announcement, Resource, Booking, ProcurementRequest, ScheduleEntry, StudentEnrollment


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
            "created_at",
        ]


class BookingSerializer(serializers.ModelSerializer):
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
        read_only_fields = ["status", "created_at"]

    def validate(self, attrs):
        start = attrs.get("start_time")
        end = attrs.get("end_time")
        resource = attrs.get("resource")
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
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["status", "reason", "created_at", "updated_at"]


class ProcurementStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProcurementRequest
        fields = ["status", "reason"]


class ScheduleEntrySerializer(serializers.ModelSerializer):
    lecturer = serializers.StringRelatedField(read_only=True)
    campus = CampusSerializer(read_only=True)
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
            "department",
            "is_postponed",
            "postponed_reason",
            "created_at",
        ]

    def get_department(self, obj):
        if hasattr(obj, 'department') and obj.department:
            return {"id": obj.department.id, "name": obj.department.name}
        return None


class PostponeClassSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, max_length=500)
