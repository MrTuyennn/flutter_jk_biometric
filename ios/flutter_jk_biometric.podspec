#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_jk_biometric.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_jk_biometric'
  s.version          = '1.0.1'
  s.summary          = 'Store a secret behind the device biometric sensor (Face ID/Touch ID/fingerprint).'
  s.description      = <<-DESC
Stores a secret string behind a hardware-backed biometric prompt (Face ID/Touch ID on iOS, BiometricPrompt on Android).
                       DESC
  s.homepage         = 'https://github.com/MrTuyennn/flutter_jk_biometric'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'MrTuyennn' => 'nguyenngoctuyen188@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_jk_biometric/Sources/flutter_jk_biometric/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_jk_biometric_privacy' => ['flutter_jk_biometric/Sources/flutter_jk_biometric/PrivacyInfo.xcprivacy']}
end
