# 🛠️ Asset Generator

A simple and flexible Dart/Flutter CLI tool to auto-generate asset reference classes like `AppImages`, `AppLottie`, or `AppLocales` from your project directories — no more hardcoding asset paths or boilerplate maintenance!

---

## ✨ Features

✅ **Automatically scans asset folders** and generates a Dart class with constant paths  
✅ **Supports nested directories** and multiple asset types (`.svg`, `.png`, `.json`, etc.)  
✅ **CamelCase variable naming**: `assets/images/ic_home.svg` → `icHome`  
✅ **Works with Flutter and pure Dart projects**  
✅ **Fully customizable class name**  
✅ **Ready to use from CLI** or programmatically

---

## 🚀 Getting Started

### 🔧 Installation

Add this package to your `dev_dependencies`:

```yaml
dev_dependencies:
  asset_generator: ^1.0.0
```

Or use the path version locally during development:

```yaml
dev_dependencies:
  asset_generator:
    path: ../asset_generator
```

Run `pub get` or `flutter pub get`.

---

### 🏃‍♂️ Usage

#### 📦 From CLI

Run the generator with:

```bash
dart run asset_generator <asset_path> [class_name]
```

**Parameters:**
- `asset_path` → **Required.** Path to your asset directory (e.g. `assets/images`)
- `class_name` → **Optional.** Name of the generated Dart class (default: `AppAssets`)

#### 💡 Example

```bash
dart run asset_generator assets/images AppImages
```

**Generates a Dart file like:**

```dart
class AppImages {
  AppImages._();
  static const String icGoogle = 'assets/images/ic_google.png';
  static const String icArrowRight = 'assets/images/ic_arrow_right.svg';
}
```

**You can now use it like:**

```dart
Image.asset(AppImages.icGoogle);
```

---

## 🛠 Output Location

The generated file will be created in your project at:

```
lib/generated/AppImages.dart
```

**Make sure `lib/generated/` is included in your `pubspec.yaml`:**

```yaml
flutter:
  assets:
    - assets/images/
```

---

## 📄 License

**MIT License**

Copyright © 2025 Divyarajsinh Jadeja

---

## ❤️ Contributions Welcome

If you find a bug or want to add a feature, feel free to open an issue or PR.

**Star ⭐ the repo if you find it helpful!**