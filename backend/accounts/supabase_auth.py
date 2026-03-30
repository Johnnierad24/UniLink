import jwt
from jwt import PyJWKClient, PyJWKClientError
from django.conf import settings
from rest_framework import authentication, exceptions
from django.contrib.auth import get_user_model
import logging

logger = logging.getLogger(__name__)
User = get_user_model()

SUPABASE_JWKS_CACHE = {}


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
    
    def _get_jwks_client(self, supabase_url):
        """Get or create JWKS client for the given Supabase URL."""
        if supabase_url not in SUPABASE_JWKS_CACHE:
            jwks_url = f"https://{supabase_url}/v1/.well-known/jwks.json"
            SUPABASE_JWKS_CACHE[supabase_url] = PyJWKClient(jwks_url, cache_keys=True)
        return SUPABASE_JWKS_CACHE[supabase_url]
    
    def _authenticate_credentials(self, token):
        try:
            supabase_url = getattr(settings, 'SUPABASE_URL', 'avdpjuwxhgrbctikddnx.supabase.co')
            
            jwks_client = self._get_jwks_client(supabase_url)
            
            signing_key = jwks_client.get_signing_key_from_jwt(token)
            
            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=['RS256'],
                audience='authenticated',
                options={
                    'verify_exp': True,
                    'verify_iat': True,
                    'require': ['exp', 'iat', 'sub', 'email']
                }
            )
            
            email = payload.get('email')
            if not email:
                raise exceptions.AuthenticationFailed('Invalid token: no email')
            
            user = User.objects.filter(email__iexact=email).first()
            
            if not user:
                raise exceptions.AuthenticationFailed(
                    'Account not found. Please contact administrator to provision your account.'
                )
            
            if not user.is_active:
                raise exceptions.AuthenticationFailed('User account is disabled.')
            
            return (user, token)
            
        except PyJWKClientError as e:
            logger.error(f"JWKS client error: {e}")
            raise exceptions.AuthenticationFailed('Unable to validate token. Please try again.')
        except jwt.ExpiredSignatureError:
            raise exceptions.AuthenticationFailed('Token has expired.')
        except jwt.InvalidAudienceError:
            raise exceptions.AuthenticationFailed('Invalid token audience.')
        except jwt.InvalidTokenError as e:
            logger.warning(f"Invalid token: {e}")
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
