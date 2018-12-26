# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + "/spec_helper")
require "pp"

describe "AndroidApk" do
  apk = nil
  apk2 = nil
  apk3 = nil
  icon_not_set_apk = nil

  mockdir = File.join(File.dirname(__FILE__), "mock")
  sample_file_path = File.join(mockdir, "sample.apk")
  sample2_file_path = File.join(mockdir, "BarcodeScanner4.2.apk")
  sample_space_file_path = File.join(mockdir, "sample with space.apk")
  icon_not_set_file_path = File.join(mockdir, "UECExpress.apk")
  dummy_file_path = File.join(mockdir, "dummy.apk")
  dsa_file_path = File.join(mockdir, "dsa.apk")
  vector_file_path = File.join(mockdir, "vector-icon.apk")
  vector_v26_file_path = File.join(mockdir, "vector-icon-v26.apk")
  multi_application_tag_file_path = File.join(mockdir, "multi_application_tag.apk")
  unsigned_file_path = File.join(mockdir, "app-release-unsigned.apk")

  it "Sample apk file exist" do
    File.exist?(sample_file_path).should == true
    File.exist?(sample2_file_path).should == true
    File.exist?(sample_space_file_path).should == true
    File.exist?(unsigned_file_path).should == true
  end

  it "Library can not read apk file" do
    apk = AndroidApk.analyze(sample_file_path + "dummy")
    apk.should.nil?
  end

  it "Library can not read invalid apk file" do
    apk = AndroidApk.analyze(dummy_file_path)
    apk.should.nil?
  end

  it "Library can read apk file" do
    apk = AndroidApk.analyze(sample_file_path)
    apk.should_not.nil?
    apk2 = AndroidApk.analyze(sample2_file_path)
    apk2.should_not.nil?
    apk3 = AndroidApk.analyze(unsigned_file_path)
    apk3.should_not.nil?
  end

  it "Can read apk information" do
    expect(apk.icon).to eq("res/drawable-mdpi/ic_launcher.png")
    expect(apk.label).to eq("sample")
    expect(apk.package_name).to eq("com.example.sample")
    expect(apk.version_code).to eq("1")
    expect(apk.version_name).to eq("1.0")
    expect(apk.sdk_version).to eq("7")
    expect(apk.target_sdk_version).to eq("15")
    expect(apk.labels).to include("ja" => "サンプル")
    expect(apk.labels.size).to eq(1)
  end

  it "Can detect signed" do
    expect(apk.signed?).to be_truthy
    expect(apk2.signed?).to be_truthy
    expect(apk3.signed?).to be_falsey
  end

  it "Can read signature" do
    apk.signature.should == "c1f285f69cc02a397135ed182aa79af53d5d20a1"
  end

  it "Can read apk3 signature" do
    apk3.signature.should.nil?
  end

  it "Icon file unzip" do
    apk.icons.length.should == 3
    apk.icon_file.should_not.nil?
    apk.icon_file(apk.icons.keys[0]).should_not.nil?
  end

  it "Can read apk information 2" do
    expect(apk2.icon).to eq("res/drawable/launcher_icon.png")
    expect(apk2.label).to eq("Barcode Scanner")
    expect(apk2.package_name).to eq("com.google.zxing.client.android")
    expect(apk2.version_code).to eq("84")
    expect(apk2.version_name).to eq("4.2")
    expect(apk2.sdk_version).to eq("7")
    expect(apk2.target_sdk_version).to eq("7")
    expect(apk2.labels).to include("ja" => "QRコードスキャナー")
    expect(apk2.labels.size).to eq(29)
  end

  it "Icon file unzip 2" do
    apk2.icons.length.should == 3
    apk2.icon_file.should_not.nil?
    apk2.icon_file(120).should_not.nil?
    apk2.icon_file("120").should_not.nil?
    apk2.icon_file(160).should_not.nil?
    apk2.icon_file(240).should_not.nil?
  end

  it "Can read signature 2" do
    apk2.signature.should == "e460df681d330f93f92e712cd79985d99379f5e0"
  end

  it "If icon has not set returns nil" do
    icon_not_set_apk = AndroidApk.analyze(icon_not_set_file_path)
    icon_not_set_apk.should_not.nil?
    icon_not_set_apk.icon_file.should.nil?
  end

  context "with space character filename" do
    subject { AndroidApk.analyze(sample_space_file_path) }
    it "returns analyzed data" do
      is_expected.not_to be_nil
    end
  end

  context "with DSA signing" do
    subject { AndroidApk.analyze(dsa_file_path) }
    it "returns analyzed data" do
      is_expected.not_to be_nil
    end
    it "can extract signature" do
      expect(subject.signature).to eq("2d8068f79a5840cbce499b51821aaa6c775ff3ff")
    end
  end

  shared_examples_for "vector icon" do
    it "can be analyzed" do
      is_expected.not_to be_nil
    end
    it "has xml icon" do
      expect(subject.icon_file).not_to be_nil
    end
    it "can return png icon" do
      expect(subject.icon_file(nil, true)).not_to be_nil
    end
    it "can return png icon by specific dpi" do
      expect(subject.icon_file(240, true)).not_to be_nil
    end
  end

  context "with vector icon" do
    subject { AndroidApk.analyze(vector_file_path) }
    it_behaves_like "vector icon"
  end

  context "with vector icon v26" do
    subject { AndroidApk.analyze(vector_v26_file_path) }
    it_behaves_like "vector icon"
  end

  context "multi application tag error" do
    it "should raise error" do
      expect do
        AndroidApk.analyze(multi_application_tag_file_path)
      end.to raise_error AndroidApk::AndroidManifestValidateError
    end

    it "not raise error" do
      expect do
        AndroidApk.analyze(vector_file_path)
      end.not_to raise_error
    end
  end

  context "check all apk installable?" do
    it do
      AndroidApk.analyze(sample_file_path).installable?.should == true
      AndroidApk.analyze(sample2_file_path).installable?.should == true
      AndroidApk.analyze(sample_space_file_path).installable?.should == true
      AndroidApk.analyze(icon_not_set_file_path).installable?.should == true
      AndroidApk.analyze(dsa_file_path).installable?.should == true
      AndroidApk.analyze(vector_file_path).installable?.should == true
      AndroidApk.analyze(vector_v26_file_path).installable?.should == true
      AndroidApk.analyze(unsigned_file_path).installable?.should == false
    end
  end
end
