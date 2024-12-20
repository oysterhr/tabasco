# frozen_string_literal: true

RSpec.describe Tabasco::Portal do
  subject { portal_klass.load }

  let(:portal_klass) do
    Class.new(described_class) do
      ensure_loaded { container }
    end
  end

  before do
    Capybara.current_session.visit "portal_test.html"
  end

  context "when the default portal has not been configured" do
    specify do
      expect { subject }.to raise_error(Tabasco::PortalNotConfigured)
    end
  end

  context "when the default portal has been configured and retrieves a container" do
    around do |lorem|
      Tabasco.configure do |config|
        config.portal do
          find("[data-portal-container]")
        end
      end

      lorem.call

      Tabasco.reset_configuration!
    end

    it "finds a portal using the configured portal block" do
      expect { subject }.not_to raise_error

      expect(subject.container).to have_content("This is the portal")
    end
  end
end
