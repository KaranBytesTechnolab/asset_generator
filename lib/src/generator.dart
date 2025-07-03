// ignore_for_file: avoid_print

import 'dart:io';

/// ---------- ASSET GENERATOR ----------
Future<void> generateAssets({required String directoryPath, String className = 'AppAssets'}) async {
  final assetDir = Directory(directoryPath);
  if (!assetDir.existsSync()) {
    print('❌ Directory does not exist: $directoryPath');
    return;
  }

  final buffer = StringBuffer();
  buffer.writeln('/// Auto-generated. Do not modify by hand.');
  buffer.writeln('class $className {\n  $className._();\n');

  final files = assetDir.listSync(recursive: true).whereType<File>().where((f) => !f.path.endsWith('.DS_Store')).toList();

  for (var file in files) {
    final relativePath = file.path.replaceAll('\\', '/');
    final fileName = relativePath.split('/').last;
    final varName = _toCamelCase(fileName.replaceAll(RegExp(r'\.\w+$'), ''));
    buffer.writeln("  static const String $varName = '$relativePath';");
  }

  buffer.writeln('}');

  final fileName = '${className.toSnakeCase()}.g.dart';
  final outputFile = File('lib/generated/$fileName');
  await outputFile.create(recursive: true);
  await outputFile.writeAsString(buffer.toString());

  print('✅ lib/generated/$fileName generated with ${files.length} assets.');
}

/// ---------- BARREL GENERATOR ----------
Future<void> generateBarrelFile({required String directoryPath, String barrelFileName = 'exports'}) async {
  final excludedFiles = ['firebase_options_dev.dart', 'firebase_options_stg.dart'];
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) {
    print('❌ Directory does not exist: $directoryPath');
    return;
  }

  final dartFiles =
      dir.listSync(recursive: true).whereType<File>().where((f) {
        final fileName = f.uri.pathSegments.last;
        return f.path.endsWith('.dart') && fileName != '${barrelFileName.toSnakeCase()}.dart' && !excludedFiles.contains(fileName);
      }).toList();

  dartFiles.sort((a, b) => a.path.compareTo(b.path));

  final buffer = StringBuffer();
  for (var file in dartFiles) {
    final relativePath = file.path.replaceFirst('$directoryPath/', '').replaceAll('\\', '/');
    buffer.writeln("export '$relativePath';");
  }

  final fileName = '${barrelFileName.toSnakeCase()}.dart';
  final barrelFile = File('$directoryPath/$fileName');
  await barrelFile.writeAsString(buffer.toString());

  print('📦 $directoryPath/$fileName generated with ${dartFiles.length} exports.');
}

/// ---------- MODULE GENERATOR ----------
Future<void> generateModuleFromArgs(List<String> args) async {
  final argsMap = {
    for (var e in args)
      if (e.contains('=')) e.split('=').first: e.split('=').last,
  };

  final name = argsMap['name'];
  final location = argsMap['location'];
  final exportPath = argsMap['export'];

  if (name == null || location == null) {
    print(
      '❌ Missing required arguments.\nUsage:\n'
      'dart run smart_asset_generator module name=home location=lib/modules [export=lib/exports.dart]',
    );
    return;
  }

  await generateModule(name: name, location: location, exportFilePath: exportPath ?? 'lib/exports.dart');
}

Future<void> handleNotificationHandlerArgs(List<String> args) async {
  final argsMap = {
    for (var e in args)
      if (e.contains('=')) e.split('=').first: e.split('=').last,
  };

  final path = argsMap['path'];
  if (path == null) {
    print(
      '❌ Missing required argument: path\nUsage:\n  dart run smart_asset_generator notification path=lib/common/notification_handler.dart',
    );
    return;
  }

  await generateNotificationHandler(outputPath: path);
}

Future<void> generateModule({required String name, required String location, required String exportFilePath}) async {
  final baseDir = Directory('$location/$name');
  final bindingDir = Directory('${baseDir.path}/bindings');
  final controllerDir = Directory('${baseDir.path}/controller');
  final viewDir = Directory('${baseDir.path}/view');

  await bindingDir.create(recursive: true);
  await controllerDir.create(recursive: true);
  await viewDir.create(recursive: true);

  final snake = name.toSnakeCase();
  final pascal = name.toPascalCase();

  final bindingPath = '$location/$name/bindings/${snake}_binding.dart';
  final controllerPath = '$location/$name/controller/${snake}_controller.dart';
  final viewPath = '$location/$name/view/${snake}_page.dart';

  // Confirm overwrite if any file exists
  final existingFiles = [File(bindingPath), File(controllerPath), File(viewPath)].where((f) => f.existsSync()).toList();

  if (existingFiles.isNotEmpty) {
    stdout.write('⚠️ One or more files already exist. Overwrite? (y/n): ');
    final response = stdin.readLineSync();
    if (response?.toLowerCase() != 'y') {
      print('❌ Aborted module generation.');
      return;
    }
  }

  await File(bindingPath).writeAsString(_bindingTemplate(pascal));
  await File(controllerPath).writeAsString(_controllerTemplate(pascal));
  await File(viewPath).writeAsString(_pageTemplate(pascal));

  final project = getProjectName();
  String stripLib(String path) => path.startsWith('lib/') ? path.substring(4) : path;

  final exportLines = [
    "export 'package:$project/${stripLib(bindingPath)}';",
    "export 'package:$project/${stripLib(controllerPath)}';",
    "export 'package:$project/${stripLib(viewPath)}';",
  ];

  final exportFile = File(exportFilePath);
  final exists = exportFile.existsSync();
  final current = exists ? await exportFile.readAsString() : '';

  final buffer = StringBuffer(current.trim());
  buffer.writeln("\n");
  for (final line in exportLines) {
    if (!current.contains(line)) {
      buffer.writeln(line);
    }
  }

  await exportFile.create(recursive: true);
  await exportFile.writeAsString('${buffer.toString().trim()}\n');

  print('✅ Module "$name" created at $location/$name');
  print('📦 Exports added to $exportFilePath');
}

/// ---------- CLONE GENERATOR ----------
Future<void> cloneProject({
  required String newProjectName,
  required String androidPackage,
  required String iosPackage,
  String? path,
}) async {
  final currentDir = Directory.current;
  final oldProjectName = getProjectName();
  final baseDir = path != null ? Directory(path) : currentDir.parent;

  // ✅ Validate custom path
  if (!await baseDir.exists()) {
    print('❌ Provided path does not exist: ${baseDir.path}');
    return;
  }
  if (!baseDir.statSync().type.toString().contains('directory')) {
    print('❌ Provided path is not a directory: ${baseDir.path}');
    return;
  }

  final newDir = Directory('${baseDir.path}/$newProjectName');

  if (await newDir.exists()) {
    print('❌ Directory already exists: ${newDir.path}');
    return;
  }

  // 1. Copy entire project directory
  await Process.run('cp', ['-R', currentDir.path, newDir.path]);

  // 2. Replace project name in pubspec.yaml
  final pubspecFile = File('${newDir.path}/pubspec.yaml');
  if (await pubspecFile.exists()) {
    final content = await pubspecFile.readAsString();
    final updated = content.replaceFirst('name: $oldProjectName', 'name: $newProjectName');
    await pubspecFile.writeAsString(updated);
  }

  // 3. Replace package imports and project name in all files
  final allFiles = newDir
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) =>
            !f.path.endsWith('.png') &&
            !f.path.endsWith('.jpg') &&
            !f.path.endsWith('.webp') &&
            !f.path.contains('/.git/') &&
            !f.path.contains('/build/'),
      );

  // 4. Rename and update android/{oldProjectName}_android.iml
  final androidIml = File('${newDir.path}/android/${oldProjectName}_android.iml');
  final newAndroidIml = File('${newDir.path}/android/${newProjectName}_android.iml');

  if (await androidIml.exists()) {
    final content = await androidIml.readAsString();
    final updated = content.replaceAll(oldProjectName, newProjectName);
    await newAndroidIml.writeAsString(updated);
    await androidIml.delete();
  }

  for (final file in allFiles) {
    try {
      final content = await file.readAsString();
      final updated = content
          .replaceAll("package:$oldProjectName/", "package:$newProjectName/")
          .replaceAll("com.example.$oldProjectName", androidPackage)
          .replaceAll(oldProjectName, newProjectName);
      await file.writeAsString(updated);
    } catch (_) {}
  }

  // 5. Rename and update .iml file
  final oldIml = File('${newDir.path}/$oldProjectName.iml');
  final newIml = File('${newDir.path}/$newProjectName.iml');
  if (await oldIml.exists()) {
    final content = await oldIml.readAsString();
    final updated = content.replaceAll(oldProjectName, newProjectName);
    await newIml.writeAsString(updated);
    await oldIml.delete();
  }

  // 6. Update Android package name
  final androidManifest = File('${newDir.path}/android/app/src/main/AndroidManifest.xml');
  final buildGradle = File('${newDir.path}/android/app/build.gradle');
  for (final file in [androidManifest, buildGradle]) {
    if (await file.exists()) {
      var content = await file.readAsString();
      content = content.replaceAll(RegExp(r'package="[^"]+"'), 'package="$androidPackage"');
      content = content.replaceAll(RegExp(r'applicationId "[^"]+"'), 'applicationId "$androidPackage"');
      await file.writeAsString(content);
    }
  }

  // 7. Update iOS bundle identifier
  final iosPlist = File('${newDir.path}/ios/Runner/Info.plist');
  if (await iosPlist.exists()) {
    var content = await iosPlist.readAsString();
    content = content.replaceAllMapped(
      RegExp(r'<key>CFBundleIdentifier</key>\s*<string>.*</string>'),
      (_) => '<key>CFBundleIdentifier</key>\n\t<string>$iosPackage</string>',
    );
    await iosPlist.writeAsString(content);
  }

  // ✅ Done
  print('✅ Project cloned to ${newDir.path}');
  print('📦 Android package: $androidPackage');
  print('📦 iOS bundle ID: $iosPackage');
}

/// ---------- NOTIFICATION HANDLER GENERATOR ----------
Future<void> generateNotificationHandler({
  required String outputPath,
  String? exportFilePath, // optional
}) async {
  final file = File(outputPath);
  final project = getProjectName();

  final content = '''
import 'package:$project/exports.dart';

/// 📲 Notification Handler
/// This class handles all notification-related functionality
class NotificationHandler {
  static const String _tag = '🔔 NotificationHandler';

  /// Initialize Firebase Cloud Messaging
  static Future<void> initialize() async {
    try {
      // Initialize FCM with a callback for notification taps
      await FCMInitializer.initialize(
        onTap: (payload) {
          print('\$_tag Local Notification tapped with payload: \$payload');

          // Convert string payload to Map if needed
          final data = {'route': payload};
          handleNotificationTap(RemoteMessage(data: data));
        },
        firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      );

      final token = await getDeviceToken();
      print('\$_tag Device token: \$token');
    } catch (e) {
      print('\$_tag Error initializing FCM: \$e');
    }
  }

  static Future<String?> getDeviceToken() async {
    try {
      final token = await FCMInitializer.getDeviceToken();
      return token;
    } catch (e) {
      print('\$_tag Error getting device token: \$e');
      return null;
    }
  }

  static void handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final route = data['route'];

    print('\$_tag Notification tapped: \$data');

    if (route != null) {
      print('\$_tag Navigating to \$route');
      _navigateToRoute(route);
    }
  }

  static void _navigateToRoute(String route) {
    try {
      Get.toNamed(route);
    } catch (e) {
      print('\$_tag Error navigating to route \$route: \$e');
    }
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    print('\$_tag Background message received: \${message.messageId}');
  }

  static void handleForegroundMessage(RemoteMessage message) {
    print('\$_tag Foreground message received: \${message.messageId}');
    _showLocalNotification(message);
  }

  static void _showLocalNotification(RemoteMessage message) {
    print('\$_tag Showing local notification: \${message.notification?.title}');
  }

  static Future<bool> requestPermissions() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('\$_tag Permission granted: \${settings.authorizationStatus}');
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      print('\$_tag Error requesting permissions: \$e');
      return false;
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      print('\$_tag Subscribed to topic: \$topic');
    } catch (e) {
      print('\$_tag Error subscribing to topic \$topic: \$e');
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      print('\$_tag Unsubscribed from topic: \$topic');
    } catch (e) {
      print('\$_tag Error unsubscribing from topic \$topic: \$e');
    }
  }

  static void setupMessageListeners() {
    FirebaseMessaging.onMessage.listen(handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(handleNotificationTap);
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
  }
}
''';

  await file.create(recursive: true);
  await file.writeAsString(content);
  print('✅ NotificationHandler file created at: $outputPath');

  // ✅ Auto-add to export file if provided
  if (exportFilePath != null) {
    final exportFile = File(exportFilePath);
    final exists = exportFile.existsSync();
    final current = exists ? await exportFile.readAsString() : '';

    // Compute relative path (strip "lib/")
    String relativePath = outputPath.startsWith('lib/') ? outputPath.substring(4) : outputPath;
    final exportLine = "export 'package:$project/$relativePath';";

    if (!current.contains(exportLine)) {
      final buffer = StringBuffer(current.trim());
      buffer.writeln("\n$exportLine");
      await exportFile.create(recursive: true);
      await exportFile.writeAsString('${buffer.toString().trim()}\n');
      print('📦 Export added to $exportFilePath');
    } else {
      print('ℹ️ Export already exists in $exportFilePath');
    }
  }
}


/// ---------- HELPERS ----------
String getProjectName() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) return 'your_project';
  final lines = pubspec.readAsLinesSync();
  for (final line in lines) {
    if (line.trim().startsWith('name:')) {
      return line.split(':').last.trim();
    }
  }
  return 'your_project';
}

String _bindingTemplate(String name) {
  final project = getProjectName();
  return '''
import 'package:$project/exports.dart';

class ${name}Binding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ${name}Controller());
  }
}
''';
}

String _controllerTemplate(String name) {
  final project = getProjectName();
  return '''
import 'package:$project/exports.dart';

class ${name}Controller extends GetxController {
  @override
  void onInit() {
    print("$name Controller initialized");
    super.onInit();
  }
}
''';
}

String _pageTemplate(String name) {
  final project = getProjectName();
  return '''
import 'package:$project/exports.dart';

class ${name}Page extends GetView<${name}Controller> {
  const ${name}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$name Page')),
      body: const Center(child: Text('Welcome to $name')),
    );
  }
}
''';
}

/// ---------- CASE CONVERSIONS ----------
String _toCamelCase(String input) {
  final sanitized = input.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  final parts = sanitized.split('_');
  return parts.first.toLowerCase() + parts.skip(1).map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)).join();
}

extension SnakeCaseExtension on String {
  String toSnakeCase() {
    return replaceAllMapped(RegExp(r'(?<=[a-z])[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}').toLowerCase();
  }

  String toPascalCase() {
    return split('_').map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '').join();
  }
}
