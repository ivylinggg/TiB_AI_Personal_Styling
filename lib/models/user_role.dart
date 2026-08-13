enum UserRole { customer, admin }

extension UserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.customer:
        return 'customer';

      case UserRole.admin:
        return 'admin';
    }
  }

  static UserRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;

      case 'customer':
      default:
        return UserRole.customer;
    }
  }
}
