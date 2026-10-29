abstract final class AppPaths {
  static const medication = '/medication';
  static const family = '/family';
  static const account = '/account';
  static const addDevice = '/add-device';
  static const selfCheck = '/self-check';
  static const policy = '/settings/policy';
  static const privacy = '/settings/privacy';
  static const notifications = '/settings/notifications';
  static const help = '/settings/help';
  static const about = '/settings/about';

  static String alert(String id) => '/alerts/$id';

  static String device(String id) => '/devices/$id';
}
