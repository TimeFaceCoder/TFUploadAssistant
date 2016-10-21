Pod::Spec.new do |s|
  s.name         = "TFUploadAssistant"
  s.version      = "0.0.1"
  s.summary      = "时光流影iOS 阿里云上传工具"
  s.homepage     = "https://github.com/TimeFaceCoder/TFUploadAssistant"
  s.license      = "Copyright (C) 2016 TimeFace, Inc.  All rights reserved."
  s.author             = { "Melvin" => "yangmin@timeface.cn" }
  s.social_media_url   = "http://www.timeface.cn"
  s.ios.deployment_target = "7.1"
  s.source       = { :git => "https://github.com/TimeFaceCoder/TFUploadAssistant.git"}
  s.source_files  = "TFUploadAssistant/TFUploadAssistant/**/*.{h,m,c}"
  s.requires_arc = true
  s.dependency 'EGOCache'
  s.dependency 'YYDispatchQueuePool'
  s.dependency 'AliyunOSSiOS'
  s.dependency 'TFNetwork'
end
