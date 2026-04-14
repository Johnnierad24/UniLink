from django.core.management.base import BaseCommand, CommandError
from django.contrib.auth import get_user_model
from django.conf import settings
import requests

User = get_user_model()


class Command(BaseCommand):
    help = 'Provision Django users from Supabase Authentication'

    def add_arguments(self, parser):
        parser.add_argument(
            '--email',
            type=str,
            help='Provision a specific user by email',
        )
        parser.add_argument(
            '--role',
            type=str,
            default='student',
            choices=['student', 'lecturer', 'director', 'coordinator', 'procurement', 'staff', 'admin'],
            help='Role for new users (default: student)',
        )
        parser.add_argument(
            '--campus',
            type=str,
            help='Campus name (e.g., "Main Campus", "Town Campus")',
        )
        parser.add_argument(
            '--department',
            type=str,
            help='Department name (e.g., "Computer Science")',
        )
        parser.add_argument(
            '--list',
            action='store_true',
            help='List all Supabase users without creating Django users',
        )
        parser.add_argument(
            '--sync',
            action='store_true',
            help='Sync existing Django users with Supabase emails',
        )

    def get_supabase_users(self):
        supabase_url = getattr(settings, 'SUPABASE_URL', None)
        supabase_service_key = getattr(settings, 'SUPABASE_SERVICE_KEY', None)

        if not supabase_url or not supabase_service_key:
            raise CommandError(
                'SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in environment'
            )

        supabase_host = supabase_url.replace('https://', '').replace('http://', '')
        users = []
        page = 1
        while True:
            try:
                response = requests.get(
                    f'https://{supabase_host}/auth/v1/admin/users',
                    headers={
                        'apikey': supabase_service_key,
                        'Authorization': f'Bearer {supabase_service_key}',
                    },
                    params={'page': page, 'per_page': 50},
                )
                response.raise_for_status()
                data = response.json()
                if not data.get('users'):
                    break
                users.extend(data['users'])
                page += 1
            except requests.RequestException as e:
                raise CommandError(f'Failed to fetch Supabase users: {e}')

        return users

    def get_campus(self, campus_name):
        if not campus_name:
            return None
        from api.models import Campus
        try:
            return Campus.objects.get(name__iexact=campus_name)
        except Campus.DoesNotExist:
            self.stderr.write(f'Campus "{campus_name}" not found')
            return None
        except Campus.MultipleObjectsReturned:
            self.stderr.write(f'Multiple campuses match "{campus_name}"')
            return None

    def get_department(self, dept_name):
        if not dept_name:
            return None
        from api.models import Department
        try:
            return Department.objects.get(name__iexact=dept_name)
        except Department.DoesNotExist:
            self.stderr.write(f'Department "{dept_name}" not found')
            return None
        except Department.MultipleObjectsReturned:
            self.stderr.write(f'Multiple departments match "{dept_name}"')
            return None

    def handle(self, *args, **options):
        email = options.get('email')
        role = options.get('role')
        campus_name = options.get('campus')
        dept_name = options.get('department')
        list_only = options.get('list')
        sync = options.get('sync')

        if list_only:
            try:
                users = self.get_supabase_users()
                self.stdout.write(f'\nFound {len(users)} users in Supabase:\n')
                for u in users:
                    email_val = u.get('email', 'N/A')
                    confirmed = u.get('email_confirmed_at', False)
                    created = u.get('created_at', 'N/A')
                    self.stdout.write(f'  - {email_val} (confirmed: {bool(confirmed)}, created: {created[:10]})')
                return
            except CommandError as e:
                raise e
            except Exception as e:
                raise CommandError(f'Error: {e}')

        if sync:
            existing_users = User.objects.filter(is_active=True)
            synced = 0
            not_found = []
            try:
                supabase_users = self.get_supabase_users()
                supabase_emails = {u['email'].lower(): u for u in supabase_users if u.get('email')}
            except CommandError as e:
                raise e

            for user in existing_users:
                if user.email and user.email.lower() in supabase_emails:
                    synced += 1
                else:
                    not_found.append(user.email or f'User ID {user.id}')

            self.stdout.write(f'Synced: {synced} users have Supabase accounts')
            if not_found:
                self.stdout.write(f'Not found in Supabase: {len(not_found)} users')
                for email in not_found[:10]:
                    self.stdout.write(f'  - {email}')
            return

        if email:
            try:
                supabase_users = self.get_supabase_users()
            except CommandError as e:
                raise e

            target_user = next(
                (u for u in supabase_users if u.get('email', '').lower() == email.lower()),
                None
            )

            if not target_user:
                raise CommandError(f'User {email} not found in Supabase')

            if User.objects.filter(email__iexact=email).exists():
                self.stdout.write(f'User {email} already exists in Django')
                return

            campus = self.get_campus(campus_name)
            department = self.get_department(dept_name)

            username = email.split('@')[0]
            base_username = username
            counter = 1
            while User.objects.filter(username=username).exists():
                username = f'{base_username}{counter}'
                counter += 1

            user = User.objects.create_user(
                username=username,
                email=email,
                role=role,
                campus=campus,
                department=department,
            )

            self.stdout.write(
                self.style.SUCCESS(f'Created user: {email} (username: {username}, role: {role})')
            )
            return

        self.stdout.write(
            '\nUsage examples:\n'
            '  python manage.py provision_supabase_users --list\n'
            '  python manage.py provision_supabase_users --email user@unilink.edu --role student\n'
            '  python manage.py provision_supabase_users --email lecturer@unilink.edu --role lecturer --campus "Main Campus" --department "Computer Science"\n'
            '  python manage.py provision_supabase_users --sync\n'
        )
