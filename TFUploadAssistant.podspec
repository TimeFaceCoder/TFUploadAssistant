#
# Be sure to run `pod lib lint TFUploadAssistant.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TFUploadAssistant'
  s.version          = '0.1.2'
  s.summary          = '时光流影文件上传辅助工具'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/TimeFaceCoder/TFUploadAssistant'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Melvin' => 'yangmin@timeface.cn' }
  s.source           = { :git => 'https://github.com/TimeFaceCoder/TFUploadAssistant.git', :branch => 'lib_demo' }
  s.social_media_url = 'https://twitter.com/melvin0204'

  s.ios.deployment_target = '8.0'

  s.platform     = :ios, '8.0'

  s.source_files = 'TFUploadAssistant/Classes/**/*'

  # s.resource_bundles = {
  #   'TFUploadAssistant' => ['TFUploadAssistant/Assets/*.png']
  # }

  s.public_header_files = [
    'TFUploadAssistant/Classes/TFUploadAssistant.h',
    'TFUploadAssistant/Classes/TFUploadCommon/TFFileProtocol.h',
    'TFUploadAssistant/Classes/TFUploadCommon/TFPHAssetFile.h',
    'TFUploadAssistant/Classes/TFConfiguration.h',
    'TFUploadAssistant/Classes/TFUploadOperationProtocol.h'
  ]
  s.frameworks = 'UIKit', 'MobileCoreServices'
  s.dependency 'AFNetworking'
  s.dependency 'EGOCache'
  s.dependency 'AliyunOSSiOS'
  s.dependency 'YYDispatchQueuePool'

end
