enum UserRole { customer, consultant, admin }

extension UserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.customer:
        return 'customer';
      case UserRole.consultant:
        return 'consultant';
      case UserRole.admin:
        return 'admin';
    }
  }

  static UserRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'consultant':
      case 'staff':
        return UserRole.consultant;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }
}
