from django.core.management.base import BaseCommand
from django.db import connection


class Command(BaseCommand):
    help = 'Apply PostgreSQL Row Level Security (RLS) policies'

    def handle(self, *args, **options):
        if connection.vendor != 'postgresql':
            self.stdout.write(
                self.style.WARNING('PostgreSQL RLS is only supported on PostgreSQL databases')
            )
            return

        self.stdout.write('Applying RLS policies...')

        policies = [
            # Enable RLS on tables
            ("ALTER TABLE api_booking ENABLE ROW LEVEL SECURITY;", "api_booking"),
            ("ALTER TABLE api_procurementrequest ENABLE ROW LEVEL SECURITY;", "api_procurementrequest"),
            ("ALTER TABLE api_studentenrollment ENABLE ROW LEVEL SECURITY;", "api_studentenrollment"),
            ("ALTER TABLE api_eventguest ENABLE ROW LEVEL SECURITY;", "api_eventguest"),
            ("ALTER TABLE api_eventpatron ENABLE ROW LEVEL SECURITY;", "api_eventpatron"),
        ]

        with connection.cursor() as cursor:
            for sql, table in policies:
                try:
                    cursor.execute(sql)
                    self.stdout.write(f'  Enabled RLS on {table}')
                except Exception as e:
                    self.stdout.write(f'  {table}: {e}')

        # Create RLS policies
        rls_policies = [
            """
            DROP POLICY IF EXISTS api_booking_user_policy ON api_booking;
            CREATE POLICY api_booking_user_policy ON api_booking
            FOR ALL
            USING (
                user_id = (current_setting('app.current_user_id', true))::integer
                OR EXISTS (
                    SELECT 1 FROM accounts_user 
                    WHERE accounts_user.id = (current_setting('app.current_user_id', true))::integer 
                    AND accounts_user.role IN ('admin', 'staff')
                )
            );
            """,
            """
            DROP POLICY IF EXISTS api_procurementrequest_user_policy ON api_procurementrequest;
            CREATE POLICY api_procurementrequest_user_policy ON api_procurementrequest
            FOR ALL
            USING (
                requested_by_id = (current_setting('app.current_user_id', true))::integer
                OR EXISTS (
                    SELECT 1 FROM accounts_user 
                    WHERE accounts_user.id = (current_setting('app.current_user_id', true))::integer 
                    AND accounts_user.role IN ('admin', 'staff')
                )
            );
            """,
            """
            DROP POLICY IF EXISTS api_studentenrollment_user_policy ON api_studentenrollment;
            CREATE POLICY api_studentenrollment_user_policy ON api_studentenrollment
            FOR ALL
            USING (
                student_id = (current_setting('app.current_user_id', true))::integer
                OR EXISTS (
                    SELECT 1 FROM accounts_user 
                    WHERE accounts_user.id = (current_setting('app.current_user_id', true))::integer 
                    AND accounts_user.role IN ('admin', 'staff')
                )
            );
            """,
            """
            DROP POLICY IF EXISTS api_eventguest_user_policy ON api_eventguest;
            CREATE POLICY api_eventguest_user_policy ON api_eventguest
            FOR ALL
            USING (
                user_id = (current_setting('app.current_user_id', true))::integer
                OR EXISTS (
                    SELECT 1 FROM accounts_user 
                    WHERE accounts_user.id = (current_setting('app.current_user_id', true))::integer 
                    AND accounts_user.role IN ('admin', 'staff')
                )
            );
            """,
        ]

        with connection.cursor() as cursor:
            for policy_sql in rls_policies:
                try:
                    cursor.execute(policy_sql)
                except Exception as e:
                    self.stdout.write(f'  Policy creation: {e}')

        self.stdout.write(
            self.style.SUCCESS('RLS policies applied successfully!')
        )
        self.stdout.write('')
        self.stdout.write('Note: RLS policies are enforced at the database level.')
        self.stdout.write('For full protection, also configure app.current_user_id in your connection pool.')
