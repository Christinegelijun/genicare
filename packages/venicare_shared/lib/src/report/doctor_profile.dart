import 'package:venicare_shared/src/report/report_models.dart';

class DoctorProfile {
  const DoctorProfile({
    required this.id,
    required this.name,
    required this.organization,
    required this.department,
    required this.title,
    this.departmentId = '',
    this.specialties = '',
    this.isAdmin = false,
  });

  factory DoctorProfile.fromJson(Json json) {
    return DoctorProfile(
      id: json['id']! as String,
      name: json['name']! as String,
      organization: json['organization']! as String,
      department: json['department']! as String,
      title: json['title']! as String,
      departmentId: json['departmentId'] as String? ?? '',
      specialties: json['specialties'] as String? ?? '',
      isAdmin: json['isAdmin'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String organization;

  /// Display name of the department; [departmentId] is the stable key.
  final String department;
  final String title;
  final String departmentId;
  final String specialties;

  /// May open the scheduling and live-status admin page.
  final bool isAdmin;

  Json toJson() => {
    'id': id,
    'name': name,
    'organization': organization,
    'department': department,
    'title': title,
    'departmentId': departmentId,
    'specialties': specialties,
    'isAdmin': isAdmin,
  };
}
