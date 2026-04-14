from rest_framework_simplejwt.views import TokenObtainPairView
from .auth import EmailOrIDTokenSerializer


class EmailOrIDTokenView(TokenObtainPairView):
    serializer_class = EmailOrIDTokenSerializer
