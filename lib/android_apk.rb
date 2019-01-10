# frozen_string_literal: true

require 'fileutils'
require "open3"
require "shellwords"
require "tmpdir"
require "zip"

class AndroidApk
  attr_accessor :results, :label, :labels, :icon, :icons, :package_name, :version_code, :version_name, :sdk_version, :target_sdk_version, :filepath

  NOT_ALLOW_DUPLICATE_TAG_NAMES = %w(application).freeze

  DPI_TO_NAME_MAP = {
    120 => "ldpi",
    160 => "mdpi",
    240 => "hdpi",
    320 => "xhdpi",
    480 => "xxhdpi",
    640 => "xxxhdpi",
  }.freeze

  SUPPORTED_DPIS = DPI_TO_NAME_MAP.keys.freeze

  class AndroidManifestValidateError < StandardError
  end

  # Do analyze the given apk file. Analyzed apk does not mean *valid*.
  #
  # @param [String] filepath a filepath of an apk to be analyzed
  # @raise [AndroidManifestValidateError] if AndroidManifest.xml has multiple application tags.
  # @return [AndroidApk, nil] An instance of AndroidApk will be returned if no problem exists while analyzing. Otherwise nil.
  def self.analyze(filepath)
    @current_warn_invalid_date = Zip.warn_invalid_date

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

  # Get an application icon file of this apk file.
  #
  # @param [Integer] dpi one of (see SUPPORTED_DPIS)
  # @param [Boolean] want_png request a png icon expressly
  # @return [File, nil] an application icon file object in temp dir
  def icon_file(dpi = nil, want_png = false)
    Zip.warn_invalid_date = false

    icon = dpi ? self.icons[dpi.to_i] : self.icon
    return nil if icon.empty?

    if want_png && icon.end_with?(".xml")
      dpis = dpi_str(dpi)
      icon.gsub! %r{res/(drawable|mipmap)-anydpi-(?:v\d+)/([^/]+)\.xml}, "res/\\1-#{dpis}-v4/\\2.png"
    end

    Dir.mktmpdir do |dir|
      output_to = File.join(dir, self.icon)

      FileUtils.mkdir_p(File.dirname(output_to))

      Zip::File.open(self.filepath) do |zip_file|
        content = zip_file.find_entry(self.icon)&.get_input_stream&.read

        File.open(output_to, "w") do |f|
          f.write(content)
        end if content
      end

      return nil unless File.exist?(output_to)

      return File.new(output_to, "r")
    end
  ensure
    Zip.warn_invalid_date = @current_warn_invalid_date
  end

  # whether or not this apk supports adaptive icon
  #
  # @return [Boolean]
  def adaptive_icon?
    Zip.warn_invalid_date = false

    if self.icon.end_with?(".xml") && self.icon.start_with?("res/mipmap-anydpi-v26/")
      adaptive_icon_path = "res/mipmap-xxxhdpi-v4/#{File.basename(self.icon).gsub(/\.xml\Z/, '.png')}"

      Zip::File.open(self.filepath) do |zip_file|
        !zip_file.find_entry(adaptive_icon_path).nil?
      end
    end
  ensure
    Zip.warn_invalid_date = @current_warn_invalid_date
  end

  # dpi to android drawable resource config name
  #
  # @param [Integer] dpi one of (see SUPPORTED_DPIS)
  # @return [String] (see SUPPORTED_DPIS). Return "xxxhdpi" if (see dpi) is not in (see SUPPORTED_DPIS)
  def dpi_str(dpi)
    DPI_TO_NAME_MAP[dpi.to_i] || "xxxhdpi"
  end

  # Whether or not this apk is installable
  #
  # @return [Boolean, nil] this apk is installable if true, otherwise not installable.
  def installable?
    # TODO: add not testable
    signed?
  end

  # Whether or not this apk is signed but this depends on (see signature)
  #
  # @return [Boolean, nil] this apk is signed if true, otherwise not signed.
  def signed?
    !signature.nil?
  end

  # The SHA-1 signature of this apk
  #
  # @return [String, nil] Return nil if cannot extract sha1 hash, otherwise the value will be returned.
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

  # Parse values of aapt output
  #
  # @param [String, nil] str a values string of aapt output.
  # @return [Array, Hash, nil] return nil if (see str) is nil. Otherwise the parsed array will be returned.
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

  # Parse output of a line of aapt command like `key: values`
  #
  # @param [String, nil] line a line of aapt command.
  # @return [[String, Hash], nil] return nil if (see line) is nil. Otherwise the parsed hash will be returned.
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

  # Parse output of aapt command to Hash format
  #
  # @param [String, nil] results output of aapt command. this may be multi lines.
  # @return [Hash, nil] return nil if (see str) is nil. Otherwise the parsed hash will be returned.
  def self._parse_aapt(results)
    vars = {}
    results.split("\n").each do |line|
      key, value = _parse_line(line)
      next if key.nil?

      if vars.key?(key)
        reject_illegal_duplicated_key!(key)

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

  # @param [String] key a key of AndroidManifest.xml
  # @raise [AndroidManifestValidateError] if a key is found in (see NOT_ALLOW_DUPLICATE_TAG_NAMES)
  def self.reject_illegal_duplicated_key!(key)
    raise AndroidManifestValidateError, "Duplication of #{key} tag is not allowed" if NOT_ALLOW_DUPLICATE_TAG_NAMES.include?(key)
  end
end
