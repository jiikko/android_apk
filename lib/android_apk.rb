# frozen_string_literal: true

require "tmpdir"
require "shellwords"
require "open3"

class AndroidApk
  attr_accessor :results, :label, :labels, :icon, :icons, :package_name, :version_code, :version_name, :sdk_version, :target_sdk_version, :filepath

  NOT_ALLOW_DUPLICATE_TAG_NAMES = %w(application).freeze

  class AndroidManifestValidateError < StandardError
  end

  def self.analyze(filepath)
    return nil unless File.exist?(filepath)

    apk = AndroidApk.new
    command = "aapt dump badging #{filepath.shellescape} 2>&1"
    results = `#{command}`
    if $?.exitstatus != 0 or results.index("ERROR: dump failed")
      return nil
    end

    apk.filepath = filepath
    apk.results = results
    vars = _parse_aapt(results)

    # application info
    apk.label = vars["application-label"]
    apk.icon = vars["application"]["icon"]

    # package

    apk.package_name = vars["package"]["name"]
    apk.version_code = vars["package"]["versionCode"]
    apk.version_name = vars["package"]["versionName"]

    # platforms
    apk.sdk_version = vars["sdkVersion"]
    apk.target_sdk_version = vars["targetSdkVersion"]

    # icons and labels
    apk.icons = {}
    apk.labels = {}
    vars.each_key do |k|
      apk.icons[Regexp.last_match(1).to_i] = vars[k] if k =~ /^application-icon-(\d+)$/
      apk.labels[Regexp.last_match(1)] = vars[k] if k =~ /^application-label-(\S+)$/
    end

    return apk
  end

  def icon_file(dpi = nil, want_png = false)
    icon = dpi ? self.icons[dpi.to_i] : self.icon
    return nil if icon.empty?

    if want_png && icon.end_with?(".xml")
      dpis = dpi_str(dpi)
      icon.gsub! %r{res/(drawable|mipmap)-anydpi-(?:v\d+)/([^/]+)\.xml}, "res/\\1-#{dpis}-v4/\\2.png"
    end

    Dir.mktmpdir do |dir|
      command = "unzip #{self.filepath.shellescape} #{icon.shellescape} -d #{dir.shellescape} 2>&1"
      `#{command}`
      path = dir + "/" + icon
      return nil unless File.exist?(path)

      return File.new(path, "r")
    end
  end

  def dpi_str(dpi)
    case dpi.to_i
    when 120
      "ldpi"
    when 160
      "mdpi"
    when 240
      "hdpi"
    when 320
      "xhdpi"
    when 480
      "xxhdpi"
    when 640
      "xxxhdpi"
    else
      "xxxhdpi"
    end
  end

  def installable?
    # TODO: add not testable
    signed?
  end

  def signed?
    !signature.nil?
  end

  def signature
    return @signature if defined? @signature

    @signature = lambda {
      command = "unzip -p #{self.filepath.shellescape} META-INF/*.RSA META-INF/*.DSA | keytool -printcert | grep SHA1:"
      output, _, status = Open3.capture3(command)
      return if status != 0 || output.nil? || !output.index("SHA1:")

      val = output.scan(/(?:[0-9A-Z]{2}:?){20}/)
      return nil if val.nil? || val.length != 1

      return val[0].delete(":").downcase
    }.call
  end

  # workaround for https://code.google.com/p/android/issues/detail?id=160847
  def self._parse_values_workaround(str)
    return nil if str.nil?

    str.scan(/^'(.+)'$/).map { |v| v[0].gsub(/\\'/, "'") }
  end

  def self._parse_values(str)
    return nil if str.nil?

    if str.index("='")
      # key-value hash
      vars = Hash[str.scan(/(\S+)='((?:\\'|[^'])*)'/)]
      vars.each_value { |v| v.gsub(/\\'/, "'") }
    else
      # values array
      vars = str.scan(/'((?:\\'|[^'])*)'/).map { |v| v[0].gsub(/\\'/, "'") }
    end
    return vars
  end

  def self._parse_line(line)
    return nil if line.nil?

    info = line.split(":", 2)
    values =
      if info[0].start_with?("application-label")
        _parse_values_workaround info[1]
      else
        _parse_values info[1]
      end
    return info[0], values
  end

  def self._parse_aapt(results)
    vars = {}
    results.split("\n").each do |line|
      key, value = _parse_line(line)
      next if key.nil?

      if vars.key?(key) && allow_duplicate?(key)
        if vars[key].kind_of?(Hash) and value.kind_of?(Hash)
          vars[key].merge(value)
        else
          vars[key] = [vars[key]] unless vars[key].kind_of?(Array)
          if value.kind_of?(Array)
            vars[key].concat(value)
          else
            vars[key].push(value)
          end
        end
      else
        vars[key] = if value.nil? || value.kind_of?(Hash)
                      value
                    else
                      value.length > 1 ? value : value[0]
                    end
      end
    end
    return vars
  end

  def self.allow_duplicate?(key)
    raise AndroidManifestValidateError, "Duplication of #{key} tag is not allowed" if NOT_ALLOW_DUPLICATE_TAG_NAMES.include?(key)

    true
  end
end
