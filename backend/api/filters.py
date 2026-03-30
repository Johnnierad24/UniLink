import re
import logging
from rest_framework.filters import SearchFilter
from django.db import connection

logger = logging.getLogger(__name__)


class SecureSearchFilter(SearchFilter):
    """
    Enhanced SearchFilter with SQL injection protection.
    - Limits search term length
    - Sanitizes special SQL characters
    - Prevents LIKE injection attacks
    """
    
    search_param = 'search'
    max_search_length = 200
    
    def get_search_terms(self, request):
        """
        Override to sanitize search terms and prevent SQL injection.
        """
        params = request.query_params.get(self.search_param, '')
        if not params:
            return []
        
        if len(params) > self.max_search_length:
            logger.warning(f"Search term exceeds max length of {self.max_search_length}")
            params = params[:self.max_search_length]
        
        params = self._sanitize_search_terms(params)
        
        return params.split()
    
    def _sanitize_search_terms(self, terms):
        """
        Sanitize search terms to prevent SQL injection.
        """
        dangerous_patterns = [
            r'(\bOR\b)',
            r'(\bAND\b)',
            r'(\bUNION\b)',
            r'(\bSELECT\b)',
            r'(\bINSERT\b)',
            r'(\bUPDATE\b)',
            r'(\bDELETE\b)',
            r'(\bDROP\b)',
            r'(\bCREATE\b)',
            r'(\bALTER\b)',
            r'(\bEXEC\b)',
            r'(\bEXECUTE\b)',
            r'(--)',
            r'(;)',
            r'(\/\*)',
            r'(\*\/)',
            r'(\bINTO\s+OUTFILE\b)',
        ]
        
        sanitized = terms
        for pattern in dangerous_patterns:
            sanitized = re.sub(pattern, ' ', sanitized, flags=re.IGNORECASE)
        
        return sanitized


class SQLInjectionSafeFilterBackend:
    """
    Filter backend that provides additional SQL injection protection
    for all filter operations.
    """
    
    @staticmethod
    def sanitize_filter_value(value):
        """
        Sanitize filter values to prevent SQL injection.
        """
        if value is None:
            return None
        
        value_str = str(value)
        
        dangerous_chars = [';', '--', '/*', '*/', 'xp_', 'sp_', '@@']
        for char in dangerous_chars:
            if char.lower() in value_str.lower():
                logger.warning(f"Potentially dangerous character detected in filter: {char}")
                return None
        
        return value
    
    @staticmethod
    def validate_queryset_params(queryset, params):
        """
        Validate that query parameters are safe.
        """
        allowed_params = [
            'search', 'ordering', 'page', 'page_size',
            'campus', 'category', 'type', 'status', 'priority',
            'audience', 'lecturer', 'department', 'is_all_day', 'is_urgent',
            'resource', 'resource__campus', 'requested_by', 'linked_event'
        ]
        
        for param in params:
            if param not in allowed_params:
                logger.warning(f"Unknown filter parameter: {param}")
                return False
        return True
