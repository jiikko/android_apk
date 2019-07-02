# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + "/spec_helper")

describe "AndroidApk" do
  subject { AndroidApk.analyze(apk_filepath) }

  FIXTURE_DIR = File.join(File.dirname(__FILE__), "mock")

  shared_examples_for :analyzable do
    it "should exist" do
      expect(File.exist?(apk_filepath)).to be_truthy
    end

    it "should be analyzable" do
      expect(subject).not_to be_nil
    end

    it "should not raise any error when getting an icon file" do
      expect { subject.icon_file }.not_to raise_exception
      expect { subject.icon_file(subject.icons.max, false) }.not_to raise_exception
      expect { subject.icon_file(subject.icons.max, true) }.not_to raise_exception
    end
  end

  context "if invalid sample apk files are given" do
    context "no such apk file" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "no_such_file") }

      it "should not exist" do
        expect(File.exist?(apk_filepath)).to be_falsey
      end

      it "should not raise any exception but not be analyzable" do
        expect(subject).to be_nil
      end
    end

    context "not an apk file" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "dummy.apk") }

      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should not raise any exception but not be analyzable" do
        expect(subject).to be_nil
      end
    end

    context "multi_application_tag.apk which has multiple application tags" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "multi_application_tag.apk") }

      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should raise error" do
        expect { subject }.to raise_error(AndroidApk::AndroidManifestValidateError)
      end
    end
  end

  context "if valid sample apk files are given" do
    %w(sample.apk sample\ with\ space.apk).each do |apk_name|
      context "#{apk_name} which is a very simple sample" do
        let(:apk_filepath) { File.join(FIXTURE_DIR, apk_name) }

        include_examples :analyzable

        it "should have icon drawable" do
          expect(subject.icon).to eq("res/drawable-mdpi/ic_launcher.png")
        end

        it "should have label stuff" do
          expect(subject.label).to eq("sample")
          expect(subject.labels).to include("ja" => "サンプル")
          expect(subject.labels.size).to eq(1)
        end

        it "should have package stuff" do
          expect(subject.package_name).to eq("com.example.sample")
          expect(subject.version_code).to eq("1")
          expect(subject.version_name).to eq("1.0")
        end

        it "should have sdk version stuff" do
          expect(subject.sdk_version).to eq("7")
          expect(subject.target_sdk_version).to eq("15")
        end

        it "should have signature" do
          expect(subject.signature).to eq("c1f285f69cc02a397135ed182aa79af53d5d20a1")
        end

        it "should multiple icons for each dimensions" do
          expect(subject.icons.length).to eq(3)
          expect(subject.icons.keys.empty?).to be_falsey
          expect(subject.icon_file).not_to be_nil
          expect(subject.icon_file(subject.icons.keys[0])).not_to be_nil
        end

        it "should be signed" do
          expect(subject.signed?).to be_truthy
        end

        it "should be installable" do
          expect(subject.installable?).to be_truthy
        end

        it "should not be adaptive icon" do
          expect(subject.adaptive_icon?).to be_falsey
        end
      end
    end

    context "BarcodeScanner4.2.apk whose icon is in drawable dir" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "BarcodeScanner4.2.apk") }

      include_examples :analyzable

      it "should have icon drawable" do
        expect(subject.icon).to eq("res/drawable/launcher_icon.png")
      end

      it "should have label stuff" do
        expect(subject.label).to eq("Barcode Scanner")
        expect(subject.labels).to include("ja" => "QRコードスキャナー")
        expect(subject.labels.size).to eq(29)
      end

      it "should have package stuff" do
        expect(subject.package_name).to eq("com.google.zxing.client.android")
        expect(subject.version_code).to eq("84")
        expect(subject.version_name).to eq("4.2")
      end

      it "should have sdk version stuff" do
        expect(subject.sdk_version).to eq("7")
        expect(subject.target_sdk_version).to eq("7")
      end

      it "should have signature" do
        expect(subject.signature).to eq("e460df681d330f93f92e712cd79985d99379f5e0")
      end

      it "should multiple icons for each dimensions" do
        expect(subject.icons.length).to eq(3)
        expect(subject.icons.keys.empty?).to be_falsey
        expect(subject.icon_file).not_to be_nil
        expect(subject.icon_file(120)).not_to be_nil
        expect(subject.icon_file(160)).not_to be_nil
        expect(subject.icon_file(240)).not_to be_nil
        expect(subject.icon_file("120")).not_to be_nil
      end

      it "should be signed" do
        expect(subject.signed?).to be_truthy
      end

      it "should be installable" do
        expect(subject.installable?).to be_truthy
      end

      it "should not be adaptive icon" do
        expect(subject.adaptive_icon?).to be_falsey
      end
    end

    context "app-release-unsigned.apk which is not signed" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "app-release-unsigned.apk") }

      include_examples :analyzable

      it "should not be signed" do
        expect(subject.signed?).to be_falsey
      end

      it "should not expose signature" do
        expect(subject.signature).to be_nil
      end

      it "should not be installable" do
        expect(subject.installable?).to be_falsey
      end
    end

    context "UECExpress.apk which does not have icons" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "UECExpress.apk") }

      include_examples :analyzable

      it "should be no icon file" do
        expect(subject.icon_file).to be_nil
        expect(subject.icon_file(nil, true)).to be_nil
      end

      it "should be installable" do
        expect(subject.installable?).to be_truthy
      end
    end

    context "dsa.apk which has been signed with DSA" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "dsa.apk") }

      include_examples :analyzable

      it "should also return its signature" do
        expect(subject.signature).to eq("2d8068f79a5840cbce499b51821aaa6c775ff3ff")
      end

      it "should be installable" do
        expect(subject.installable?).to be_truthy
      end
    end

    shared_examples :vector_icon_apk do
      include_examples :analyzable

      it "should have non-png icon" do
        expect(subject.icon_file).not_to be_nil
      end

      it "should return png icon by specific dpi" do
        expect(subject.icon_file(240, true)).not_to be_nil
      end

      it "should be installable" do
        expect(subject.installable?).to be_truthy
      end
    end

    context "vector-icon.apk whose icon is a vector file" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "vector-icon.apk") }

      it_should_behave_like :vector_icon_apk

      it "should have png icon" do
        expect(subject.icon_file(nil, true)).not_to be_nil
      end

      it "should not be adaptive icon" do
        expect(subject.adaptive_icon?).to be_falsey
      end
    end

    context "vector-icon-v26.apk whose icon is an adaptive icon" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "vector-icon-v26.apk") }

      it_should_behave_like :vector_icon_apk

      it "should have png icon" do
        expect(subject.icon_file(nil, true)).not_to be_nil
      end

      it "should be an adaptive icon" do
        expect(subject.adaptive_icon?).to be_truthy
      end
    end

    %w(vector-icon-v26-non-adaptive-icon.apk vector-icon-v26-non-adaptive-icon\ with\ space.apk).each do |apk_name|
      context "#{apk_name} whose icon is not an adaptive icon" do
        let(:apk_filepath) { File.join(FIXTURE_DIR, apk_name) }

        it_should_behave_like :vector_icon_apk

        it "should not have png icon" do
          expect(subject.icon_file(nil, true)).to be_nil
        end

        it "should be an adaptive icon" do
          expect(subject.adaptive_icon?).to be_falsey
        end
      end
    end
  end
end
