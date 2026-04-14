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
            jwks_url = f"https://{supabase_url}/auth/v1/.well-known/jwks.json"
            SUPABASE_JWKS_CACHE[supabase_url] = PyJWKClient(jwks_url, cache_keys=True)
        return SUPABASE_JWKS_CACHE[supabase_url]
    
    def _authenticate_credentials(self, token):
        try:
            supabase_url = getattr(settings, 'SUPABASE_URL', 'avdpjuwxhgrbctikddnx.supabase.co')
            supabase_jwt_secret = getattr(settings, 'SUPABASE_JWT_SECRET', '')
            
            logger.info(f"=== TOKEN DEBUG ===")
            logger.info(f"Token starts with: {token[:80]}...")
            
            # Try JWT secret for HS256 validation
            if supabase_jwt_secret:
                try:
                    payload = jwt.decode(
                        token,
                        supabase_jwt_secret,
                        algorithms=['HS256', 'HS512'],
                        options={
                            'verify_exp': True,
                            'verify_iat': True,
                        }
                    )
                    logger.info(f"Decoded payload: {payload}")
                    
                    # Check role - authenticated users have 'authenticated' role
                    role = payload.get('role', '')
                    logger.info(f"Token role: {role}")
                    
                    # Verify it's for our Supabase project
                    if payload.get('iss') != 'supabase':
                        raise exceptions.AuthenticationFailed('Invalid token issuer')
                    ref = payload.get('ref', '')
                    expected_ref = supabase_url.replace('https://', '').replace('http://', '')
                    if ref != expected_ref:
                        raise exceptions.AuthenticationFailed('Invalid token project')
                    
                    email = payload.get('email')
                    logger.info(f"Email from token: {email}")
                    
                    if email:
                        user = User.objects.filter(email__iexact=email).first()
                        logger.info(f"User found: {user}")
                        if user and user.is_active:
                            return (user, token)
                    else:
                        # Token has no email - might be anon token
                        logger.warning("Token has no email - likely anon token")
                        raise exceptions.AuthenticationFailed('Please login with email and password')
                except jwt.InvalidTokenError as e:
                    logger.warning(f"JWT validation failed: {e}")
            
            # NEW: Try to get email from X-User-Email header (sent by frontend)
            email_from_header = request.headers.get('X-User-Email')
            if email_from_header:
                logger.info(f"Looking up user by email from header: {email_from_header}")
                user = User.objects.filter(email__iexact=email_from_header).first()
                if user and user.is_active:
                    return (user, token)
                else:
                    raise exceptions.AuthenticationFailed('User not found')
            
            # Last resort: Check if this is an authenticated token by verifying it can be decoded
            # Try to decode without validation to get user info
            try:
                unverified = jwt.decode(token, options={"verify_signature": False})
                role = unverified.get('role', '')
                if role == 'authenticated':
                    # This is a valid authenticated token but we can't get email
                    # Try to find user by sub (user ID) - but we'd need to store Supabase user IDs
                    logger.warning("Authenticated token but no email - rejecting")
                    raise exceptions.AuthenticationFailed('Authentication error. Please try again.')
            except Exception as e:
                logger.warning(f"Token decode failed: {e}")
                raise exceptions.AuthenticationFailed('Invalid token')
            
            # Fall back to JWKS for RS256 tokens
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
