Pod::Spec.new do |spec|
  spec.name = 'AMCoreAudio'
  spec.version = '3.4'
  spec.summary = 'A Swift framework that makes Core Audio less tedious on macOS'
  spec.homepage = 'https://github.com/rnine/AMCoreAudio'
  spec.license = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.author = { 'Ruben Nine' => 'ruben@9labs.io' }

  spec.platform = :osx, '11.0'
  spec.source = {
    :git => 'https://github.com/rnine/AMCoreAudio.git',
    :tag => '3.4'
  }

  # The published 3.4 podspec used Source/* and omitted the implementation,
  # which is nested under Source/Public and Source/Internal.
  spec.source_files = 'Source/**/*.{swift,h,m}'
  spec.public_header_files = 'Source/AMCoreAudio.h'
  spec.requires_arc = true
  spec.swift_version = '5.2'
end
