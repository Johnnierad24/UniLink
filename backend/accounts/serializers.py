from rest_framework import serializers
from .models import User
from api.serializers import CampusSerializer


class UserBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "username", "email", "role"]


class UserSerializer(serializers.ModelSerializer):
    campus = CampusSerializer(read_only=True)
    department = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "role",
            "campus",
            "department",
            "avatar_url",
            "notification_prefs",
        ]

    def get_campus_id(self):
        from api.models import Campus
        return Campus.objects.all()

    def get_department(self, obj):
        if obj.department:
            return {"id": obj.department.id, "name": obj.department.name, "code": obj.department.code}
        return None
