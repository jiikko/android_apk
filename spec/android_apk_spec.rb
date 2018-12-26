# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + "/spec_helper")
require "pp"

describe "AndroidApk" do
  apk = nil
  apk2 = nil
  apk3 = nil
  icon_not_set_apk = nil

  mockdir                         = File.join(File.dirname(__FILE__), "mock")
  sample_file_path                = File.join(mockdir, "sample.apk")
  sample2_file_path               = File.join(mockdir, "BarcodeScanner4.2.apk")
  sample_space_file_path          = File.join(mockdir, "sample with space.apk")
  icon_not_set_file_path          = File.join(mockdir, "UECExpress.apk")
  dummy_file_path                 = File.join(mockdir, "dummy.apk")
  dsa_file_path                   = File.join(mockdir, "dsa.apk")
  vector_file_path                = File.join(mockdir, "vector-icon.apk")
  vector_v26_file_path            = File.join(mockdir, "vector-icon-v26.apk")
  multi_application_tag_file_path = File.join(mockdir, "multi_application_tag.apk")
  unsigned_file_path              = File.join(mockdir, "app-release-unsigned.apk")

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
    apk.icon.should == "res/drawable-mdpi/ic_launcher.png"
    apk.label.should == "sample"
    apk.package_name.should == "com.example.sample"
    apk.version_code.should == "1"
    apk.version_name.should == "1.0"
    apk.sdk_version.should == "7"
    apk.target_sdk_version.should == "15"
    apk.labels.length.should == 1
    apk.labels["ja"].should == "サンプル"
  end

  it "Can detect signed" do
    apk.signed?.should == true
    apk2.signed?.should == true
    apk3.signed?.should == false
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
    apk2.icon.should == "res/drawable/launcher_icon.png"
    apk2.label.should == "Barcode Scanner"
    apk2.package_name.should == "com.google.zxing.client.android"
    apk2.version_code.should == "84"
    apk2.version_name.should == "4.2"
    apk2.sdk_version.should == "7"
    apk2.target_sdk_version.should == "7"
    apk2.labels.length.should == 29
    apk2.labels["ja"].should == "QRコードスキャナー"
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
