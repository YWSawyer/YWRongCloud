
Pod::Spec.new do |s|

  s.name         = "YWRongCloud"
  s.version      = "0.0.1"
  s.summary      = "YWRongCloudCall is base on callkit-ios,but it is not support cocoapods,So it just support cocoapods "
  s.description  = <<-DESC 
                      Open-source code of RongCloud VoIP Audio/Video UI
                   DESC

  s.homepage     = "https://github.com/YWSawyer/YWRongCloud"

  s.license      = "MIT"

  s.author             = { "YWSawyer" => "yuan_wei_1@163.com" }
  # s.authors            = { "YWSawyer" => "yuan_wei_1@163.com" }
  # s.social_media_url   = "http://twitter.com/YWSawyer"

  s.platform     = :ios, "8.0"
  s.ios.deployment_target = "8.0"

  s.source       = { :git => "https://github.com/YWSawyer/YWRongCloud.git", :tag => s.version }

  s.source_files  = "YWRongCloud/*", "*.{h,m,mm}"

  # s.exclude_files = "Classes/Exclude"
  # s.public_header_files = "Classes/**/*.h"
  # s.resource  = "icon.png"
  # s.resources = "Resources/*.png"
  # s.preserve_paths = "FilesToSave", "MoreFilesToSave"


  # s.framework  = "SomeFramework"
  s.frameworks = 'Foundation', 'UIKit'

  # s.library   = "iconv"
  # s.libraries = "iconv", "xml2"

  s.requires_arc = true

  # s.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }
   s.dependency 'RongCloudIM/IMLib', '2.8.0'
   s.dependency 'RongCloudIM/IMKit', '2.8.0'
   s.dependency 'RongCloudIM/CallLib', '2.8.0'

end
