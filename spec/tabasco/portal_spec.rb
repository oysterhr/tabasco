# frozen_string_literal: true

RSpec.describe Tabasco::Portal do
  subject { portal_klass.load }

  let(:handle) { :portal_container }

  let(:portal_klass) do
    portal_handle = handle

    Class.new(described_class) do
      handle portal_handle
      ensure_loaded { container }
    end
  end

  before do
    Capybara.current_session.visit "portal_test.html"
  end

  context "without a handle" do
    let(:handle) { nil }

    it "raises Tabasco::Portal::MissingHandleError" do
      expect { subject }.to raise_error(Tabasco::Portal::MissingHandleError)
    end
  end

  context "when the given portal handle has been properly configured" do
    around do |example|
      Tabasco.configure do |config|
        config.portal(:portal_container)
        config.portal(:datepicker, test_id: :datepicker_container)
      end

      example.call

      Tabasco.reset_configuration!
    end

    it "finds the container anywhere in the DOM using the handle as test_id" do
      expect { subject }.not_to raise_error

      expect(subject).to have_content("This is the portal")
    end

    context "with an explicit test_id" do
      let(:handle) { :datepicker }

      it "finds the container anywhere in the DOM using the explicit test_id" do
        expect { subject }.not_to raise_error

        expect(subject).to have_content("This is a floating datepicker element.")
      end
    end
  end
end
