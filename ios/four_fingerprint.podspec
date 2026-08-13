#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint four_fingerprint.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'four_fingerprint'
  s.version          = '1.0.0'
  s.summary          = 'Contactless slap fingerprint capture plugin — 4-4-2 sequencing, minutiae extraction, and matching via phone camera.'
  s.description      = <<-DESC
Captures four-finger slap images via phone camera and produces match-ready fingerprint templates.
                       DESC
  s.homepage         = 'https://github.com/your-repo/four_fingerprint'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*', '../src/*.c', '../src/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
