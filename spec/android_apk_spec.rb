# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + "/spec_helper")
require "pp"
require "yaml"

describe "AndroidApk" do
  let(:subject_apk) { AndroidApk.analyze(apk_filepath) }

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

  context "check preconditions for this spec" do
    it "should have sample apk files" do
      expect(File.exist?(sample_file_path)).to be_truthy
      expect(File.exist?(sample2_file_path)).to be_truthy
      expect(File.exist?(sample_space_file_path)).to be_truthy
      expect(File.exist?(unsigned_file_path)).to be_truthy
    end
  end

  context "if invalid apk files are given" do
    shared_examples :no_exception_but_nil do |message, apk_filepath|
      context message do
        let(:apk_filepath) { apk_filepath }

        it "should not raise any exception but return nil" do
          expect(subject_apk).to be_nil
        end
      end
    end

    include_examples :no_exception_but_nil, "not found", sample_file_path + "dummy"
    include_examples :no_exception_but_nil, "not valid apk files", dummy_file_path
  end

  context "if valid apk files are given" do
    context "sample.apk" do
      let(:apk_filepath) { sample_file_path }

      it "should return non-nil" do
        expect(subject_apk).not_to be_nil
      end

      it "should have icon drawable" do
        expect(subject_apk.icon).to eq("res/drawable-mdpi/ic_launcher.png")
      end

      it "should have label stuff" do
        expect(subject_apk.label).to eq("sample")
        expect(subject_apk.labels).to include("ja" => "サンプル")
        expect(subject_apk.labels.size).to eq(1)
      end

      it "should have package stuff" do
        expect(subject_apk.package_name).to eq("com.example.sample")
        expect(subject_apk.version_code).to eq("1")
        expect(subject_apk.version_name).to eq("1.0")
      end

      it "should have sdk version stuff" do
        expect(subject_apk.sdk_version).to eq("7")
        expect(subject_apk.target_sdk_version).to eq("15")
      end

      it "should have signature" do
        expect(subject_apk.signature).to eq("c1f285f69cc02a397135ed182aa79af53d5d20a1")
      end

      it "should multiple icons for each dimensions" do
        expect(subject_apk.icons.length).to eq(3)
        expect(subject_apk.icons.keys.empty?).to be_falsey
        expect(subject_apk.icon_file).not_to be_nil
        expect(subject_apk.icon_file(subject_apk.icons.keys[0])).not_to be_nil
      end

      it "should be signed" do
        expect(subject_apk.signed?).to be_truthy
      end
    end

    context "BarcodeScanner4.2.apk" do
      let(:apk_filepath) { sample2_file_path }

      it "should return non-nil" do
        expect(subject_apk).not_to be_nil
      end

      it "should have icon drawable" do
        expect(subject_apk.icon).to eq("res/drawable/launcher_icon.png")
      end

      it "should have label stuff" do
        expect(subject_apk.label).to eq("Barcode Scanner")
        expect(subject_apk.labels).to include("ja" => "QRコードスキャナー")
        expect(subject_apk.labels.size).to eq(29)
      end

      it "should have package stuff" do
        expect(subject_apk.package_name).to eq("com.google.zxing.client.android")
        expect(subject_apk.version_code).to eq("84")
        expect(subject_apk.version_name).to eq("4.2")
      end

      it "should have sdk version stuff" do
        expect(subject_apk.sdk_version).to eq("7")
        expect(subject_apk.target_sdk_version).to eq("7")
      end

      it "should have signature" do
        expect(subject_apk.signature).to eq("e460df681d330f93f92e712cd79985d99379f5e0")
      end

      it "should multiple icons for each dimensions" do
        expect(subject_apk.icons.length).to eq(3)
        expect(subject_apk.icons.keys.empty?).to be_falsey
        expect(subject_apk.icon_file).not_to be_nil
        expect(subject_apk.icon_file(120)).not_to be_nil
        expect(subject_apk.icon_file(160)).not_to be_nil
        expect(subject_apk.icon_file(240)).not_to be_nil
        expect(subject_apk.icon_file("120")).not_to be_nil
      end

      it "should be signed" do
        expect(subject_apk.signed?).to be_truthy
      end
    end
  end

  it "Library can read apk file" do
    apk3 = AndroidApk.analyze(unsigned_file_path)
    expect(apk3).not_to be_nil
  end

  it "Can detect signed" do
    expect(apk3.signed?).to be_falsey
  end

  it "Can read apk3 signature" do
    expect(apk3.signature).to be_nil
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
      expect { AndroidApk.analyze(multi_application_tag_file_path) }.to raise_error(AndroidApk::AndroidManifestValidateError)
    end

    it "not raise error" do
      expect { AndroidApk.analyze(vector_file_path) }.not_to raise_error
    end
  end

  context "check all apk installable?" do
    it do
      expect(AndroidApk.analyze(sample_file_path).installable?).to be_truthy
      expect(AndroidApk.analyze(sample2_file_path).installable?).to be_truthy
      expect(AndroidApk.analyze(sample_space_file_path).installable?).to be_truthy
      expect(AndroidApk.analyze(icon_not_set_file_path).installable?).to be_truthy
      expect(AndroidApk.analyze(dsa_file_path).installable?).to be_truthy
      expect(AndroidApk.analyze(vector_file_path).installable?).to be_truthy
      expect(AndroidApk.analyze(vector_v26_file_path).installable?).to be_truthy
      expect(AndroidApk.analyze(unsigned_file_path).installable?).to be_falsey
    end
  end
end
