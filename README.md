#Android APK

[![Build Status](https://travis-ci.org/DeployGate/android_apk.svg?branch=master)](https://travis-ci.org/DeployGate/android_apk)

This gem allows you to analyze Android application package file (*i.e.* .apk files.)


## Prerequisite

Please make sure the `aapt` and `apksigner` command executable.

## Installation

Add this gem to your Gemfile

```
gem 'android_apk'
```

## Usage

```ruby
require 'android_apk'

apk = AndroidApk.analyze("/path/to/apkfile.apk")

apk.sdk_version
# => "14"

apk.target_sdk_version
# => "26"

apk.label
# => "Sample"

apk.package_name
# => "com.example.sample"

apk.version_code
# => "1"

apk.version_name
# => "1.0"

apk.labels.length
# => 2

apk.labels['ja']
# => 'サンプル'

apk.signature
# => "c1f285f69cc02a397135ed182aa79af53d5d20a1"

apk.icons.length
# => 5

apk.icon
# => "res/mipmap-anydpi-v26/ic_launcher.xml"

apk.icon_file
# => File (png/xml)

apk.icon_file('hdpi')
# => File (png/xml)

apk.icon_file('hdpi', true)
# => File (png)

apk.dpi_str(240)
# => "hdpi"
```

Under [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Originally created by Kyosuke Inoue <kyoro@hakamastyle.net>