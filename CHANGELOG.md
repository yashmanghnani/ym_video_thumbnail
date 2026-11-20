## 2.0.0

* Raised the minimum SDK versions to Flutter 3.50.1 and Dart 3.14.0.
* Updated Android tooling to AGP 9.3.1 and Gradle 9.5.0.
* Migrated the example to `material_ui` and updated its image picker.
* Migrated the iOS example to the UIScene lifecycle.
* Fixed iOS decoding of percent-encoded `file://` video URLs.
* Fixed iOS thumbnail generation when only one dimension is specified.
* Fixed Android thumbnail generation when scaling rounded a dimension to zero.

## 1.0.0

* Updated package metadata and documentation for the 1.0.0 release.
* Added lowercase `ImageFormat` values while preserving legacy uppercase
  aliases as deprecated names.
* Added Dart-side validation for dimensions, timestamps, and image quality.
* Fixed the platform-channel test setup and expanded API coverage.
* Modernized Android Gradle tooling to AGP 9.1.0, Gradle 9.3.1, Java 17, and
  Android API 36.
* Improved Android resource cleanup, output-path handling, encoding errors, and
  executor shutdown behavior.
* Fixed iOS remote-file output, directory creation, Core Graphics ownership,
  and WebP encoder buffer cleanup.

## 0.0.2

* Initial release for this Flutter plugin.
