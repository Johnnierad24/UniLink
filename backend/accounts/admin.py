from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django import forms
from .models import User


class UserAdminForm(forms.ModelForm):
    class Meta:
        model = User
        fields = '__all__'


class UserCreationForm(forms.ModelForm):
    class Meta:
        model = User
        fields = ('username',)


class UserAdmin(DjangoUserAdmin):
    form = UserAdminForm
    add_form = UserCreationForm
    list_display = ('username', 'email', 'role', 'campus', 'is_staff')
    list_filter = ('role', 'campus', 'is_staff')
    search_fields = ('username', 'email')
    ordering = ('username',)


admin.site.register(User, UserAdmin)
