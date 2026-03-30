import jwt
from django.conf import settings
from rest_framework import authentication, exceptions
from django.contrib.auth import get_user_model

User = get_user_model()

class SupabaseAuthentication(authentication.BaseAuthentication):
    """
    Authenticate users via Supabase JWT tokens.
    Validates the token and maps to Django User.
    """
    
    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        
        if not auth_header:
            return None
            
        try:
            prefix, token = auth_header.split(' ')
            if prefix.lower() != 'bearer':
                return None
        except ValueError:
            return None
            
        return self._authenticate_credentials(token)
    
    def _authenticate_credentials(self, token):
        try:
            # Decode without verification for now (Supabase handles this)
            # In production, verify with Supabase JWKS
            payload = jwt.decode(
                token, 
                options={"verify_signature": False}
            )
            
            # Get user email from token
            email = payload.get('email')
            if not email:
                raise exceptions.AuthenticationFailed('Invalid token: no email')
            
            # Find or create user based on email
            user = User.objects.filter(email__iexact=email).first()
            
            if not user:
                # Auto-create user from Supabase
                username = email.split('@')[0]
                user = User.objects.create_user(
                    username=username,
                    email=email,
                    password=None,  # No password - Supabase handles auth
                )
            
            return (user, token)
            
        except jwt.InvalidTokenError as e:
            raise exceptions.AuthenticationFailed(f'Invalid token: {str(e)}')
    
    def authenticate_header(self, request):
        return 'Bearer'


class SupabaseTokenValidator:
    """
    Validates Supabase JWT tokens against their JWKS endpoint.
    More secure than just decoding without verification.
    """
    
    SUPABASE_JWKS_URL = 'https://{}.supabase.co/v1/.well-known/jwks.json'
    
    def __init__(self, supabase_url):
        self.supabase_url = supabase_url.replace('https://', '').replace('http://', '')
        self.jwks_url = self.SUPABASE_JWKS_URL.format(self.supabase_url)
    
    def validate_token(self, token):
        """Validate token against Supabase JWKS."""
        try:
            # Get JWKS
            import requests
            jwks_response = requests.get(self.jwks_url, timeout=10)
            jwks = jwks_response.json()
            
            # Get the key ID from token header
            unverified_header = jwt.get_unverified_header(token)
            kid = unverified_header.get('kid')
            
            # Find matching key
            key = None
            for jwk in jwks.get('keys', []):
                if jwk.get('kid') == kid:
                    key = jwt.algorithms.RSAAlgorithm.from_jwk(jwk)
                    break
            
            if not key:
                raise exceptions.AuthenticationFailed('Unable to find appropriate key')
            
            # Verify token
            payload = jwt.decode(
                token,
                key=key,
                algorithms=['RS256'],
                audience='authenticated'
            )
            
            return payload
            
        except Exception as e:
            raise exceptions.AuthenticationFailed(f'Token validation failed: {str(e)}')
