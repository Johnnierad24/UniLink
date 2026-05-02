enum UserRole {
  student('student'),
  lecturer('lecturer'),
  director('director'),
  coordinator('coordinator'),
  procurement('procurement'),
  staff('staff'),
  admin('admin');

  const UserRole(this.value);
  final String value;

  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.lecturer:
        return 'Lecturer';
      case UserRole.director:
        return 'Director';
      case UserRole.coordinator:
        return 'Coordinator';
      case UserRole.procurement:
        return 'Procurement';
      case UserRole.staff:
        return 'Staff';
      case UserRole.admin:
        return 'Admin';
    }
  }

  static UserRole fromApi(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.student,
    );
  }
}

class UserCapabilities {
  const UserCapabilities(this.role);

  final UserRole role;

  bool get isStudent => role == UserRole.student;
  bool get isLecturer => role == UserRole.lecturer;
  bool get isProcurement => role == UserRole.procurement;
  bool get isDirector => role == UserRole.director;
  bool get isCoordinator => role == UserRole.coordinator;
  bool get isStaffLike =>
      role == UserRole.staff ||
      role == UserRole.admin ||
      isDirector ||
      isCoordinator;

  bool get canViewProcurement =>
      isProcurement || isDirector || isCoordinator || isStaffLike;

  bool get canApproveProcurement =>
      isProcurement || role == UserRole.staff || role == UserRole.admin;

  bool get canUseBookings => !isProcurement;

  bool get canViewAllSchedules =>
      isDirector ||
      isCoordinator ||
      role == UserRole.admin ||
      role == UserRole.staff;
}
