Pod::Spec.new do |spec|
  spec.name         = 'PRHTask@aufflick'
  spec.version      = '0.0.1'
  spec.license      = { :type => 'BSD' }
  spec.homepage     = 'https://github.com/aufflick/PRHTask'
  spec.authors      = { 'Peter Hosey' => '@boredzo', 'Mark Aufflick' => 'mark@aufflick.com' }
  spec.summary      = 'A replacement for NSTask. Should be drop-in for most (eventually all) purposes.'
  spec.source       = { :git => 'https://github.com/aufflick/PRHTask.git', :tag => 'v0.0.1' }
  spec.source_files = 'PRHTask.{h,m}'
  spec.requires_arc = false
end
