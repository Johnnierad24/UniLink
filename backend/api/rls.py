"""
Row Level Security (RLS) for UniLink
Ensures users can only access their own data
"""
from rest_framework import permissions
from django.db import connection


class BaseRLSPermission(permissions.BasePermission):
    """
    Base class for Row Level Security permissions.
    Subclasses should define:
    - owner_field: the field that owns the object
    - admin_roles: roles that can access all records
    """
    owner_field = 'user'
    admin_roles = {'admin', 'staff'}
    
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated
    
    def has_object_permission(self, request, view, obj):
        user = request.user
        
        if user.role.lower() in self.admin_roles:
            return True
        
        owner = getattr(obj, self.owner_field, None)
        if owner is None:
            return False
        
        return owner.id == user.id


class IsOwner(BaseRLSPermission):
    """Permission that checks if user owns the object"""
    pass


class IsOwnerOrStaff(BaseRLSPermission):
    """Permission that allows owner or admin/staff"""
    pass


class UserRLSPermission(BaseRLSPermission):
    """For objects owned by user relationship"""
    owner_field = 'user'
    
    def has_object_permission(self, request, view, obj):
        user = request.user
        
        if user.role.lower() in self.admin_roles:
            return True
        
        return obj.user.id == user.id


class RequestedByRLSPermission(BaseRLSPermission):
    """For ProcurementRequest - uses requested_by field"""
    owner_field = 'requested_by'
    
    def has_object_permission(self, request, view, obj):
        user = request.user
        
        if user.role.lower() in self.admin_roles:
            return True
        
        return obj.requested_by.id == user.id


class LecturerRLSPermission(BaseRLSPermission):
    """For ScheduleEntry - lecturers see their own, students see their department"""
    def has_object_permission(self, request, view, obj):
        user = request.user
        
        if user.role.lower() in self.admin_roles:
            return True
        
        if obj.lecturer and obj.lecturer.id == user.id:
            return True
        
        if user.role == 'student' and obj.department:
            if hasattr(user, 'department') and user.department:
                return obj.department.id == user.department.id
        
        return False


class EventAccessPermission(BaseRLSPermission):
    """For Events - staff create, all can read"""
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return request.user and request.user.is_authenticated
    
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        
        user = request.user
        return user.role.lower() in self.admin_roles


class ResourceAccessPermission(BaseRLSPermission):
    """For Resources - staff create, all can read"""
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return request.user and request.user.is_authenticated
    
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        
        user = request.user
        return user.role.lower() in self.admin_roles


class EnrollmentRLSPermission(BaseRLSPermission):
    """For StudentEnrollment"""
    owner_field = 'student'
    
    def has_object_permission(self, request, view, obj):
        user = request.user
        
        if user.role.lower() in self.admin_roles:
            return True
        
        return obj.student.id == user.id


class EventGuestRLSPermission(BaseRLSPermission):
    """For EventGuest"""
    owner_field = 'user'
    
    def has_object_permission(self, request, view, obj):
        user = request.user
        
        if user.role.lower() in self.admin_roles:
            return True
        
        return obj.user.id == user.id


def get_postgres_rls_sql():
    """
    Generate PostgreSQL RLS policies for all models.
    Run this once to enable RLS at database level.
    """
    policies = []
    
    enable_rls = "ALTER TABLE api_booking ENABLE ROW LEVEL SECURITY;"
    policies.append(enable_rls)
    
    create_policy = """
CREATE POLICY api_booking_user_policy ON api_booking
FOR ALL
USING (
    user_id = current_setting('app.current_user_id')::integer
    OR EXISTS (
        SELECT 1 FROM accounts_user 
        WHERE accounts_user.id = current_setting('app.current_user_id')::integer 
        AND accounts_user.role IN ('admin', 'staff')
    )
);
"""
    policies.append(create_policy)
    
    return "\n".join(policies)


class PostgreSQLRLSMixin:
    """
    Mixin to set current user ID for PostgreSQL RLS.
    Add this to settings to enable PostgreSQL RLS.
    """
    @staticmethod
    def set_rls_user(user):
        if connection.vendor == 'postgresql':
            from django.db import connection
            with connection.cursor() as cursor:
                cursor.execute(
                    f"SET app.current_user_id = {user.id if user.is_authenticated else 0}"
                )
    
    def process_exception(self, request, exception):
        self.set_rls_user(request.user)
        return super().process_exception(request, exception)
    
    def finalize_response(self, request, response, *args, **kwargs):
        self.set_rls_user(request.user)
        return super().finalize_response(request, response, *args, **kwargs)
