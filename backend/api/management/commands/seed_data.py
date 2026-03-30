import random
from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from accounts.models import User
from api.models import Campus, Department, ScheduleEntry, StudentEnrollment


class Command(BaseCommand):
    help = "Bulk create test users, departments, and schedules"

    def handle(self, *args, **options):
        self.stdout.write("Starting bulk seed...\n")

        # Get or create campuses
        main_campus = Campus.objects.get_or_create(name="Main Campus", defaults={"location": "Meru, Nchiru"})[0]
        town_campus = Campus.objects.get_or_create(name="Town Campus", defaults={"location": "Meru Town, KEN"})[0]

        self.stdout.write(f"Campuses: {main_campus.name}, {town_campus.name}\n")

        # Create departments
        departments_data = [
            # Main Campus Departments
            {"name": "Computer Science", "code": "CS", "campus": main_campus},
            {"name": "Information Technology", "code": "IT", "campus": main_campus},
            {"name": "Business Administration", "code": "BA", "campus": main_campus},
            {"name": "Electrical Engineering", "code": "EE", "campus": main_campus},
            {"name": "Mechanical Engineering", "code": "ME", "campus": main_campus},
            {"name": "Education", "code": "EDU", "campus": main_campus},
            {"name": "Medicine", "code": "MED", "campus": main_campus},
            {"name": "Nursing", "code": "NUR", "campus": main_campus},
            # Town Campus Departments
            {"name": "Law", "code": "LAW", "campus": town_campus},
            {"name": "Journalism", "code": "JOUR", "campus": town_campus},
            {"name": "Hospitality Management", "code": "HM", "campus": town_campus},
            {"name": "Tourism", "code": "TOUR", "campus": town_campus},
        ]

        departments = {}
        for dept_data in departments_data:
            dept, created = Department.objects.get_or_create(
                code=dept_data["code"],
                defaults={"name": dept_data["name"], "campus": dept_data["campus"]}
            )
            departments[dept_data["code"]] = dept
            if created:
                self.stdout.write(f"  Dept: {dept.name}\n")

        self.stdout.write(f"Departments: {len(departments)}\n")

        # Create Town Campus Director
        director, created = User.objects.get_or_create(
            username="town_director",
            defaults={
                "email": "director@towncampus.unilink.edu",
                "role": "admin",
                "campus": town_campus,
            }
        )
        if created:
            director.set_password("director123")
            director.is_staff = True
            director.is_superuser = True
            director.save()
            self.stdout.write(f"  Town Campus Director: {director.username}\n")

        # Create Town Campus Coordinator
        coordinator, created = User.objects.get_or_create(
            username="town_coordinator",
            defaults={
                "email": "coordinator@towncampus.unilink.edu",
                "role": "staff",
                "campus": town_campus,
            }
        )
        if created:
            coordinator.set_password("coordinator123")
            coordinator.is_staff = True
            coordinator.save()
            self.stdout.write(f"  Town Campus Coordinator: {coordinator.username}\n")

        # Create Main Campus Procurement Officer
        procurement, created = User.objects.get_or_create(
            username="procurement_officer",
            defaults={
                "email": "procurement@maincampus.unilink.edu",
                "role": "staff",
                "campus": main_campus,
            }
        )
        if created:
            procurement.set_password("procurement123")
            procurement.save()
            self.stdout.write(f"  Procurement Officer: {procurement.username}\n")

        # Create Lecturers
        self.stdout.write("\nCreating 1000 lecturers...\n")
        lecturers = []
        lecturer_names = [
            "James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
            "William", "Elizabeth", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
            "Thomas", "Sarah", "Charles", "Karen", "Christopher", "Nancy", "Daniel", "Lisa",
            "Matthew", "Betty", "Anthony", "Margaret", "Mark", "Sandra", "Donald", "Ashley",
        ]
        lecturer_surnames = [
            "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
            "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
            "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson",
        ]

        main_depts = [departments["CS"], departments["IT"], departments["BA"], 
                      departments["EE"], departments["ME"], departments["EDU"], 
                      departments["MED"], departments["NUR"]]
        town_depts = [departments["LAW"], departments["JOUR"], departments["HM"], departments["TOUR"]]

        batch_lecturers = []
        for i in range(1, 1001):
            first = random.choice(lecturer_names)
            last = random.choice(lecturer_surnames)
            username = f"lect_{first.lower()}_{last.lower()}_{i}"
            
            # Distribute lecturers across departments
            if i <= 600:
                dept = random.choice(main_depts)
                campus = main_campus
            else:
                dept = random.choice(town_depts)
                campus = town_campus

            batch_lecturers.append(User(
                username=username,
                email=f"{username}@unilink.edu",
                first_name=first,
                last_name=last,
                role="lecturer",
                campus=campus,
                department=dept,
                university_id=f"LT{i:05d}",
            ))
            
            if len(batch_lecturers) >= 100:
                User.objects.bulk_create(batch_lecturers, ignore_conflicts=True)
                self.stdout.write(f"  Lecturers {i-99} - {i}\n")
                batch_lecturers = []

        # Create remaining lecturers
        if batch_lecturers:
            User.objects.bulk_create(batch_lecturers, ignore_conflicts=True)

        lecturers = list(User.objects.filter(role="lecturer"))
        self.stdout.write(f"Lecturers: {len(lecturers)}\n")

        # Create Students
        self.stdout.write("\nCreating 1000 students...\n")
        student_names = [
            "Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry",
            "Ivy", "Jack", "Kate", "Liam", "Mia", "Noah", "Olivia", "Peter",
            "Quinn", "Rose", "Sam", "Tina", "Uma", "Victor", "Wendy", "Xavier",
        ]

        batch_students = []
        for i in range(1, 1001):
            first = random.choice(student_names)
            last = random.choice(lecturer_surnames)
            username = f"student_{first.lower()}_{last.lower()}_{i}"
            
            # Distribute students across departments
            if i <= 700:
                dept = random.choice(main_depts)
                campus = main_campus
            else:
                dept = random.choice(town_depts)
                campus = town_campus

            batch_students.append(User(
                username=username,
                email=f"{username}@students.unilink.edu",
                first_name=first,
                last_name=last,
                role="student",
                campus=campus,
                department=dept,
                university_id=f"CT{i:05d}",
            ))
            
            if len(batch_students) >= 100:
                User.objects.bulk_create(batch_students, ignore_conflicts=True)
                self.stdout.write(f"  Students {i-99} - {i}\n")
                batch_students = []

        if batch_students:
            User.objects.bulk_create(batch_students, ignore_conflicts=True)

        students = list(User.objects.filter(role="student"))
        self.stdout.write(f"Students: {len(students)}\n")

        # Create Schedule Entries
        self.stdout.write("\nCreating schedule entries...\n")
        courses = [
            ("Introduction to Programming", "CS101", 3),
            ("Data Structures", "CS201", 4),
            ("Database Systems", "CS301", 3),
            ("Web Development", "IT101", 2),
            ("Networking", "IT201", 3),
            ("Business Ethics", "BA101", 2),
            ("Marketing Basics", "BA201", 3),
            ("Circuit Analysis", "EE101", 4),
            ("Digital Electronics", "EE201", 3),
            ("Thermodynamics", "ME101", 4),
            ("Fluid Mechanics", "ME201", 3),
            ("Pedagogy", "EDU101", 2),
            ("Anatomy", "MED101", 5),
            ("Pharmacology", "NUR201", 4),
            ("Constitutional Law", "LAW101", 3),
            ("Media Writing", "JOUR101", 2),
            ("Hotel Management", "HM101", 3),
            ("Tourism Geography", "TOUR101", 2),
        ]

        rooms = ["Room A", "Room B", "Room C", "Lab 1", "Lab 2", "Hall 1", "Hall 2", "Lecture Theatre"]
        now = timezone.now()
        schedule_entries = []

        for lecturer in lecturers[:500]:  # Create schedules for first 500 lecturers
            if not lecturer.department:
                continue
                
            num_classes = random.randint(2, 5)
            for _ in range(num_classes):
                course = random.choice(courses)
                day_offset = random.randint(0, 4)
                hour_start = random.randint(8, 15)
                
                start = now.replace(hour=hour_start, minute=0, second=0) + timedelta(days=day_offset)
                end = start + timedelta(hours=course[2])
                
                schedule_entries.append(ScheduleEntry(
                    campus=lecturer.campus,
                    title=course[0],
                    course_code=course[1],
                    room=random.choice(rooms),
                    start_time=start,
                    end_time=end,
                    enrollment_count=random.randint(20, 100),
                    lecturer=lecturer,
                    audience="student",
                    department=lecturer.department,
                ))

        # Bulk create schedules
        created_schedules = ScheduleEntry.objects.bulk_create(schedule_entries, ignore_conflicts=True)
        self.stdout.write(f"Schedule entries: {len(created_schedules)}\n")

        # Create Student Enrollments
        self.stdout.write("\nCreating student enrollments...\n")
        enrollments = []
        
        # Get schedules with departments
        schedules_by_dept = {}
        for schedule in ScheduleEntry.objects.select_related("department").all():
            if schedule.department_id:
                if schedule.department_id not in schedules_by_dept:
                    schedules_by_dept[schedule.department_id] = []
                schedules_by_dept[schedule.department_id].append(schedule)

        # Enroll students in relevant schedules
        for student in students[:500]:  # First 500 students
            if not student.department_id or student.department_id not in schedules_by_dept:
                continue
                
            # Enroll in 2-4 classes from their department
            dept_schedules = schedules_by_dept[student.department_id]
            if not dept_schedules:
                continue
                
            chosen = random.sample(dept_schedules, min(random.randint(2, 4), len(dept_schedules)))
            for schedule in chosen:
                enrollments.append(StudentEnrollment(
                    student=student,
                    schedule_entry=schedule,
                ))

        created_enrollments = StudentEnrollment.objects.bulk_create(enrollments, ignore_conflicts=True)
        self.stdout.write(f"Enrollments: {len(created_enrollments)}\n")

        # Summary
        self.stdout.write("\n" + "="*50)
        self.stdout.write("\nBULK SEED COMPLETE!\n")
        self.stdout.write("="*50)
        self.stdout.write(f"""
Summary:
  Campuses: 2
  Departments: {len(departments)}
  Students: {len(students)}
  Lecturers: {len(lecturers)}
  Schedule Entries: {len(created_schedules)}
  Enrollments: {len(created_enrollments)}

Test Credentials:
  Town Campus Director: town_director / director123
  Town Campus Coordinator: town_coordinator / coordinator123
  Procurement Officer: procurement_officer / procurement123
""")
