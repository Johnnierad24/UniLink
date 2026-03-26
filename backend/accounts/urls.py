from django.urls import path
from .views import MeView, EmailVerificationRequestView, EmailVerificationConfirmView
from .views_auth import EmailOrIDTokenView

urlpatterns = [
    path("token/", EmailOrIDTokenView.as_view(), name="token_obtain_email_or_id"),
    path("me/", MeView.as_view(), name="me"),
    path("verify/request/", EmailVerificationRequestView.as_view(), name="verify_request"),
    path("verify/confirm/", EmailVerificationConfirmView.as_view(), name="verify_confirm"),
]
