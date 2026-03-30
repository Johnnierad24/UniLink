import logging
from rest_framework.throttling import SimpleRateThrottle
from django.core.cache import cache
from ipaddress import ip_address as ip_address_fn, ip_network

logger = logging.getLogger(__name__)


class IPRateThrottle(SimpleRateThrottle):
    """
    Rate limit by IP address - prevents bot spam from single IPs.
    """
    scope = 'ip'
    
    def get_cache_key(self, request, view):
        if request.user and request.user.is_authenticated:
            return None
        
        ident = self.get_ident(request)
        return self.cache_format % {
            'scope': self.scope,
            'ident': ident
        }


class LoginRateThrottle(SimpleRateThrottle):
    """
    Strict rate limiting for login endpoints.
    Prevents brute force attacks - max 5 attempts per hour per IP.
    """
    scope = 'login'
    
    def get_cache_key(self, request, view):
        ident = self.get_ident(request)
        return f"throttle_login_{ident}"
    
    def allow_request(self, request, view):
        ident = self.get_ident(request)
        cache_key = f"throttle_login_{ident}"
        
        history = cache.get(cache_key, [])
        now = self.timer()
        
        while history and history[-1] <= now - 3600:
            history.pop()
        
        if len(history) >= 5:
            return False
        
        history.insert(0, now)
        cache.set(cache_key, history, 3600)
        return True


class ContactFormRateThrottle(SimpleRateThrottle):
    """
    Extremely strict rate limiting for contact/form submissions.
    Max 1 request per hour per IP to prevent bot spam.
    """
    scope = 'contact'
    
    def get_cache_key(self, request, view):
        ident = self.get_ident(request)
        return f"throttle_contact_{ident}"
    
    def allow_request(self, request, view):
        ident = self.get_ident(request)
        cache_key = f"throttle_contact_{ident}"
        
        last_request = cache.get(cache_key)
        if last_request:
            import time
            time_since_last = time.time() - last_request
            if time_since_last < 3600:
                return False
        
        cache.set(cache_key, time.time(), 3600)
        return True


class PasswordResetRateThrottle(SimpleRateThrottle):
    """
    Rate limiting for password reset requests.
    Max 3 requests per hour per IP.
    """
    scope = 'password_reset'
    
    def get_cache_key(self, request, view):
        ident = self.get_ident(request)
        return f"throttle_password_reset_{ident}"
    
    def allow_request(self, request, view):
        ident = self.get_ident(request)
        cache_key = f"throttle_password_reset_{ident}"
        
        history = cache.get(cache_key, [])
        now = self.timer()
        
        while history and history[-1] <= now - 3600:
            history.pop()
        
        if len(history) >= 3:
            return False
        
        history.insert(0, now)
        cache.set(cache_key, history, 3600)
        return True


class APIScopeRateThrottle(SimpleRateThrottle):
    """
    General API rate limiting with configurable scopes.
    """
    scope = 'api'
    
    def get_cache_key(self, request, view):
        if request.user and request.user.is_authenticated:
            ident = request.user.pk
        else:
            ident = self.get_ident(request)
        
        return self.cache_format % {
            'scope': self.scope,
            'ident': ident
        }


class BurstRateThrottle(SimpleRateThrottle):
    """
    Short burst protection - limits rapid requests.
    """
    scope = 'burst'
    
    def get_cache_key(self, request, view):
        ident = self.get_ident(request)
        return f"throttle_burst_{ident}"
    
    def allow_request(self, request, view):
        ident = self.get_ident(request)
        cache_key = f"throttle_burst_{ident}"
        
        request_count = cache.get(cache_key, 0)
        
        if request_count >= 10:
            return False
        
        cache.set(cache_key, request_count + 1, 60)
        return True


class AnonRootThrottle(SimpleRateThrottle):
    """
    Strict throttle for anonymous users on root/sensitive endpoints.
    """
    scope = 'anon_root'
    
    def get_cache_key(self, request, view):
        ident = self.get_ident(request)
        return self.cache_format % {
            'scope': self.scope,
            'ident': ident
        }
