Pod::Spec.new do |s|
  s.name             = 'ym_video_thumbnail'
  s.version          = '1.0.0'
  s.summary          = 'Generate video thumbnails on Android and iOS.'
  s.description      = <<-DESC
Generate image thumbnails from local video files and remote video URLs.
                       DESC
  s.homepage         = 'https://github.com/yashmanghnani/ym_video_thumbnail'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Yash Manghnani' => 'https://github.com/yashmanghnani' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'USER_HEADER_SEARCH_PATHS' => '$(inherited) ${PODS_ROOT}/libwebp/**'
  }
  s.dependency 'Flutter'
  s.dependency 'libwebp'

  s.ios.deployment_target = '15.0'
end
