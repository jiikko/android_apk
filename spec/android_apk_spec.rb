# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + "/spec_helper")

describe "AndroidApk" do
  subject { AndroidApk.analyze(apk_filepath) }

  FIXTURE_DIR = File.join(File.dirname(__FILE__), "fixture")

  shared_examples_for :analyzable do
    it "should exist" do
      expect(File.exist?(apk_filepath)).to be_truthy
    end

    it "should be analyzable" do
      expect(subject).not_to be_nil
    end

    it "should not raise any error when getting an icon file" do
      max_icon = (subject.icons.keys - [65_534, 65_535]).max

      expect { subject.icon_file }.not_to raise_exception
      expect { subject.icon_file(max_icon, false) }.not_to raise_exception
      expect { subject.icon_file(max_icon, true) }.not_to raise_exception
    end
  end

  context "if duplicated sdk_version apk are given" do
    let(:apk_filepath) { File.join(FIXTURE_DIR, "other", "duplicate_sdk_version.apk") }
    it "should raise error" do
      expect { subject }.to raise_error(AndroidApk::AndroidManifestValidateError, /Duplication of sdkVersion tag is not allowed/)
    end
  end

  context "if invalid sample apk files are given" do
    context "no such apk file" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "other", "no_such_file") }

      it "should not exist" do
        expect(File.exist?(apk_filepath)).to be_falsey
      end

      it "should not raise any exception but not be analyzable" do
        expect(subject).to be_nil
      end
    end

    context "not an apk file" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "other", "dummy.apk") }

      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should not raise any exception but not be analyzable" do
        expect(subject).to be_nil
      end
    end

    context "multi_application_tag.apk which has multiple application tags" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "other", "multi_application_tag.apk") }

      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should raise error" do
        expect { subject }.to raise_error(AndroidApk::AndroidManifestValidateError)
      end
    end
  end

  context "if valid sample apk files are given" do
    shared_examples_for :not_test_only do
      it "should not test_only?" do
        expect(subject.test_only?).to be_falsey
      end
    end

    %w(sample.apk sample\ with\ space.apk).each do |apk_name|
      context "#{apk_name} which is a very simple sample" do
        let(:apk_filepath) { File.join(FIXTURE_DIR, "other", apk_name) }

        include_examples :analyzable
        include_examples :not_test_only

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

    context "test-only.apk which has a testOnly flag" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "other", "test-only.apk") }

      include_examples :analyzable

      it "should also return its signature" do
        expect(subject.signature).to eq("89f20f82fad1be0f69d273bbdd62503e692d61b0")
      end

      it "should be signed" do
        expect(subject.signed?).to be_truthy
      end

      it "should be test_only?" do
        expect(subject.test_only?).to be_truthy
      end

      it "should not be installable" do
        expect(subject.installable?).to be_falsey
      end

      it "should have test only state" do
        expect(subject.uninstallable_reasons).to include(AndroidApk::Reason::TEST_ONLY)
      end
    end

    describe "resource aware specs" do
      shared_examples_for :assert_resource do
        let(:apk_filepath) { File.join(FIXTURE_DIR, "resource", apk_name) }

        include_examples :analyzable

        it "should have multiple icons for each dimensions" do
          expect(!subject.icons.empty?).to be_truthy
        end

        it "should have icon file" do
          expect(subject.icon_file).not_to be_nil
        end

        it "should be installable" do
          expect(subject.installable?).to be_truthy
        end
      end

      shared_examples_for :common_assert_resource do
        describe "png only icon" do
          let(:apk_name) { "png_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

          include_examples :assert_resource

          it "should have png icon file" do
            expect(subject.icon_file(subject.icons.keys.max, true)).not_to be_nil
          end

          it "should not be adaptive icon" do
            expect(subject.adaptive_icon?).to be_falsey
          end
        end

        describe "png only icon in drawable directory" do
          let(:apk_name) { "png_icon_in_drawable_only-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

          include_examples :assert_resource

          it "should have png icon file anyway!" do
            expect(subject.icon_file(subject.icons.keys.max, true)).not_to be_nil
            expect(subject.icon_file(160, true)).not_to be_nil
            expect(subject.icon_file(nil, true)).not_to be_nil
          end

          it "should not be adaptive icon" do
            expect(subject.adaptive_icon?).to be_falsey
          end
        end

        describe "no icon" do
          let(:apk_name) { "no_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

          let(:apk_filepath) { File.join(FIXTURE_DIR, "resource", apk_name) }

          include_examples :analyzable

          it "should not have png icon file" do
            expect(subject.icon_file(nil, true)).to be_nil
          end

          it "should not be adaptive icon" do
            expect(subject.adaptive_icon?).to be_falsey
          end

          it "should be installable" do
            expect(subject.installable?).to be_truthy
          end
        end
      end

      context "min sdk is less than vector drawable supported sdk" do
        let(:min_sdk) { "14" }

        include_examples :common_assert_resource

        describe "adaptive icon" do
          let(:apk_name) { "adaptive_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

          include_examples :assert_resource

          it "should have png icon file" do
            expect(subject.icon_file(subject.icons.keys.max, true)).not_to be_nil
          end

          it "should be adaptive icon" do
            expect(subject.adaptive_icon?).to be_truthy
          end

          it "should be backward compatible adaptive icon" do
            expect(subject.backward_compatible_adaptive_icon?).to be_truthy
          end
        end

        describe "misconfigured adaptive icon" do
          let(:apk_name) { "misconfigured_adaptive_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

          include_examples :assert_resource

          it "should not have png icon file" do
            expect(subject.icon_file(subject.icons.keys.max, true)).to be_nil
          end

          it "should be adaptive icon" do
            expect(subject.adaptive_icon?).to be_truthy
          end

          it "should not be backward compatible adaptive icon" do
            expect(subject.backward_compatible_adaptive_icon?).to be_falsey
          end
        end
      end

      context "min sdk is less than adaptive icon supported sdk" do
        let(:min_sdk) { "21" }

        include_examples :common_assert_resource

        describe "vd only icon" do
          let(:apk_name) { "vd_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

          include_examples :assert_resource

          it "should not have png icon file" do
            expect(subject.icon_file(subject.icons.keys.max, true)).to be_nil
          end

          it "should not be adaptive icon" do
            expect(subject.adaptive_icon?).to be_falsey
          end
        end

        describe "vd and png icon" do
          let(:apk_name) { "vd_and_png_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

          include_examples :assert_resource

          it "should have png icon file" do
            expect(subject.icon_file(subject.icons.keys.max, true)).not_to be_nil
          end

          it "should not be adaptive icon" do
            expect(subject.adaptive_icon?).to be_falsey
          end
        end

        describe "adaptive icon" do
          let(:apk_name) { "adaptive_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

          include_examples :assert_resource

          it "should have png icon file" do
            expect(subject.icon_file(subject.icons.keys.max, true)).not_to be_nil
          end

          it "should be adaptive icon" do
            expect(subject.adaptive_icon?).to be_truthy
          end

          it "should be backward compatible adaptive icon" do
            expect(subject.backward_compatible_adaptive_icon?).to be_truthy
          end
        end

        describe "misconfigured adaptive icon" do
          let(:apk_name) { "misconfigured_adaptive_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

          include_examples :assert_resource

          it "should not have png icon file" do
            expect(subject.icon_file(subject.icons.keys.max, true)).to be_nil
          end

          it "should be adaptive icon" do
            expect(subject.adaptive_icon?).to be_truthy
          end

          it "should not be backward compatible adaptive icon" do
            expect(subject.backward_compatible_adaptive_icon?).to be_falsey
          end
        end
      end

      context "min sdk is greater than adaptive icon supported sdk" do
        let(:min_sdk) { "26" }

        include_examples :common_assert_resource

        describe "vd and png icon" do
          let(:apk_name) { "vd_and_png_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

          include_examples :assert_resource

          it "should have png icon file" do
            expect(subject.icon_file(subject.icons.keys.max, true)).not_to be_nil
          end

          it "should not be adaptive icon" do
            expect(subject.adaptive_icon?).to be_falsey
          end
        end

        describe "adaptive icon" do
          let(:apk_name) { "adaptive_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

          include_examples :assert_resource

          it "should have png icon file" do
            expect(subject.icon_file(subject.icons.keys.max, true)).not_to be_nil
          end

          it "should be adaptive icon" do
            expect(subject.adaptive_icon?).to be_truthy
          end

          it "should be backward compatible adaptive icon" do
            expect(subject.backward_compatible_adaptive_icon?).to be_falsey
          end
        end

        describe "misconfigured adaptive icon" do
          let(:apk_name) { "misconfigured_adaptive_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

          include_examples :assert_resource

          it "should not have png icon file" do
            expect(subject.icon_file(nil, true)).to be_nil
          end

          it "should be adaptive icon" do
            expect(subject.adaptive_icon?).to be_truthy
          end

          it "should not be backward compatible adaptive icon" do
            expect(subject.backward_compatible_adaptive_icon?).to be_falsey
          end
        end
      end
    end

    describe "signature aware specs" do
      shared_examples_for :assert_signature do
        let(:apk_filepath) { File.join(FIXTURE_DIR, "signature", apk_name) }

        include_examples :analyzable

        it "should have signature" do
          expect(subject.signature).to eq(signature)
        end

        it "should be signed" do
          expect(subject.signed?).to be_truthy
        end

        it "should be installable" do
          expect(subject.installable?).to be_truthy
        end

        it "should have the expected min sdk version" do
          expect(subject.sdk_version).to eq(min_sdk)
        end

        it "should not have unsigned state" do
          expect(subject.uninstallable_reasons).not_to include(AndroidApk::Reason::UNSIGNED)
        end
      end

      context "no signing" do
        let(:apk_filepath) { File.join(FIXTURE_DIR, "signature", "png_icon-assembleUnsigned-v1-true-v2-true-min-14.apk") }

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

        it "should have unsigned state" do
          expect(subject.uninstallable_reasons).to include(AndroidApk::Reason::UNSIGNED)
        end
      end

      context "rsa signing" do
        let(:signature) { "4ad4e4376face4e441a3b8802363a7f6c6b458ab" }

        context "min sdk is equal or greater than v2 scheme supported sdk" do
          let(:min_sdk) { "24" }

          context "v1 and v2 schemes" do
            let(:apk_name) { "png_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

            include_examples :assert_signature
          end

          context "v1 only" do
            let(:apk_name) { "png_icon-assembleRsa-v1-true-v2-false-min-#{min_sdk}.apk" }

            include_examples :assert_signature
          end

          context "v2 only" do
            let(:apk_name) { "png_icon-assembleRsa-v1-false-v2-true-min-#{min_sdk}.apk" }

            include_examples :assert_signature
          end
        end

        context "min sdk is less than v2 scheme supported sdk" do
          let(:min_sdk) { "14" }

          context "v1 and v2 schemes" do
            let(:apk_name) { "png_icon-assembleRsa-v1-true-v2-true-min-#{min_sdk}.apk" }

            include_examples :assert_signature
          end

          context "v1 only" do
            let(:apk_name) { "png_icon-assembleRsa-v1-true-v2-false-min-#{min_sdk}.apk" }

            include_examples :assert_signature
          end

          context "v2 only" do
            let(:apk_name) { "png_icon-assembleRsa-v1-false-v2-true-min-#{min_sdk}.apk" }

            include_examples :assert_signature
          end
        end
      end

      context "dsa signing" do
        let(:signature) { "6a2dd3e16a3f05fc219f914734374065985273b3" }

        context "min sdk is equal or greater than v2 scheme supported sdk" do
          let(:min_sdk) { "24" }

          context "v1 and v2 schemes" do
            let(:apk_name) { "png_icon-assembleDsa-v1-true-v2-true-min-#{min_sdk}.apk" }

            include_examples :assert_signature
          end

          context "v1 only" do
            let(:apk_name) { "png_icon-assembleDsa-v1-true-v2-false-min-#{min_sdk}.apk" }

            include_examples :assert_signature
          end

          context "v2 only" do
            let(:apk_name) { "png_icon-assembleDsa-v1-false-v2-true-min-#{min_sdk}.apk" }

            include_examples :assert_signature
          end
        end

        context "min sdk is less than v2 scheme supported sdk" do
          let(:min_sdk) { "14" }

          context "v1 and v2 schemes" do
            let(:apk_name) { "png_icon-assembleDsa-v1-true-v2-true-min-#{min_sdk}.apk" }

            include_examples :assert_signature
          end

          context "v1 only" do
            let(:apk_name) { "png_icon-assembleDsa-v1-true-v2-false-min-#{min_sdk}.apk" }

            include_examples :assert_signature
          end

          context "v2 only" do
            let(:apk_name) { "png_icon-assembleDsa-v1-false-v2-true-min-#{min_sdk}.apk" }

            include_examples :assert_signature
          end
        end
      end
    end
  end
end
