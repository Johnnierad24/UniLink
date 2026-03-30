from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import permissions, status
from .serializers import UserSerializer
from .utils import make_verification_token, verify_token, send_verification_email
from django.contrib.auth import get_user_model

User = get_user_model()


class MeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def patch(self, request):
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)


class EmailVerificationRequestView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        if not request.user.email:
            return Response({"error": {"message": "Email is required on profile"}}, status=status.HTTP_400_BAD_REQUEST)
        send_verification_email(request.user)
        return Response({"sent": True}, status=status.HTTP_200_OK)


class EmailVerificationConfirmView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        token = request.data.get("token")
        if not token:
            return Response({"error": {"message": "Token required"}}, status=status.HTTP_400_BAD_REQUEST)
        try:
            user_id = verify_token(token)
            user = User.objects.get(id=user_id)
        except Exception:
            return Response({"error": {"message": "Invalid or expired token"}}, status=status.HTTP_400_BAD_REQUEST)
        user.email_verified = True
        user.save(update_fields=["email_verified"])
        return Response({"verified": True}, status=status.HTTP_200_OK)


class PasswordResetView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        new_password = request.data.get("new_password")

        if not new_password:
            return Response(
                {"error": {"message": "New password is required"}},
                status=status.HTTP_400_BAD_REQUEST
            )

        if len(new_password) < 6:
            return Response(
                {"error": {"message": "Password must be at least 6 characters"}},
                status=status.HTTP_400_BAD_REQUEST
            )

        user = request.user
        user.set_password(new_password)
        user.save()

        return Response(
            {"message": "Password reset successfully"},
            status=status.HTTP_200_OK
        )
