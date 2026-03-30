from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework.throttling import AnonRateThrottle
from api.throttles import LoginRateThrottle
from .auth import EmailOrIDTokenSerializer


class EmailOrIDTokenView(TokenObtainPairView):
    serializer_class = EmailOrIDTokenSerializer
    throttle_classes = [AnonRateThrottle, LoginRateThrottle]
