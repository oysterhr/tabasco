# frozen_string_literal: true

RSpec.describe Tabasco::Page do
  subject { page_klass.visit }

  let(:page) { Capybara.current_session }
  let(:page_url) { "test_page.html" }
  let(:contact_section_klass) { nil }

  let(:page_klass) do
    contact_section_klass_value = contact_section_klass
    page_url_value = page_url

    Class.new(described_class) do
      url page_url_value
      container_test_id :root_container

      ensure_loaded { has_content!("Welcome to the Testing Demo Page") }

      section :welcome_header do
        portal :another_portal
      end

      section :top_menu
      section :about do
        section :first_article
        section :second_article
        portal :my_portal
      end
      section :contact, contact_section_klass_value
      section :non_existing_section

      section :does_not_load_properly, test_id: "contact" do
        ensure_loaded { has_content!("This string does not exist in the contact section") }
      end
    end
  end

  describe "scoping capybara node methods" do
    it "scopes the content to the whole page" do
      expect(subject).to have_content("Welcome to the Testing Demo Page")
      expect(subject).to have_content("Home")
      expect(subject).to have_content("Home Section")
      expect(subject).to have_content("Article 1")
      expect(subject).to have_content("Additional Information")
      expect(subject).to have_content("Contact Section")
    end

    it "scopes the content to subsections" do
      expect(subject.welcome_header).to have_content("Welcome to the Testing Demo Page")
      expect(subject.welcome_header).to have_no_content("Contact Section")

      expect(subject.contact).to have_no_content("Welcome to the Testing Demo Page")
      expect(subject.contact).to have_content("Contact Section")
    end

    it "scopes the content to deeply nested subsections" do
      expect(subject.about).to have_content("About Section")
      expect(subject.about).to have_content("Article 1")
      expect(subject.about).to have_content("Article 2")

      expect(subject.about.first_article).to have_content("Article 1")
      expect(subject.about.first_article).to have_no_content("Article 2")
      expect(subject.about.first_article).to have_no_content("About Section")

      expect(subject.about.second_article).to have_content("Article 2")
      expect(subject.about.second_article).to have_no_content("Article 1")
      expect(subject.about.second_article).to have_no_content("About Section")
    end
  end

  # rubocop: disable RSpec/ExpectInLet
  describe "providing defined section classes" do
    let(:contact_section_klass) do
      Class.new(Tabasco::Section) do
        container_test_id "contact"

        ensure_loaded { has_content!("Contact Section") }

        section :header, test_id: :contact_header
        section :form, test_id: :contact_form
      end
    end

    it "returns instances of the given class" do
      expect(subject.contact).to be_a(contact_section_klass)
    end

    it "exposes and scopes nested sections correctly" do
      expect(subject.contact).to have_content("Contact Section")
      expect(subject.contact.header).to have_content("Contact Section")

      expect(subject.contact.form).to have_content("Email:")
      expect(subject.contact.form).to have_no_content("Contact Section")
    end
  end
  # rubocop: enable RSpec/ExpectInLet

  context "when the page fails to load properly" do
    let(:page_url) { "oops_not_found.html" }

    it "raises an expectation error when trying to use the page object" do
      # TODO: wrap with Tabasco:: custom error class and improve error message
      expect { subject }
        .to raise_error(Capybara::ElementNotFound, "Unable to find css \"[data-testid='root-container']\"")
    end
  end

  it "raises Capybara::ElementNotFound when trying to interact with sections not rendered in the page" do
    # TODO: wrap with Tabasco:: custom error class and improve error message
    expect { subject.non_existing_section }
      .to raise_error(Capybara::ElementNotFound, "Unable to find css \"[data-testid='non-existing-section']\"")
  end

  context "when the ensure_loaded block for a section fails" do
    it "raises Tabasco::PreconditionNotMetError" do
      # TODO: error message can definitely be improved
      expect { subject.does_not_load_properly }
        .to raise_error(
          Tabasco::PreconditionNotMetError,
          "has_content!: Expected has_content? to return truthy, but it returned false",
        )
    end
  end

  describe "portals" do
    around do |example|
      Tabasco.configure do |config|
        config.portal(:my_portal)
        config.portal(:another_portal, test_id: :another_portal_container)
      end

      example.call

      Tabasco.reset_configuration!
    end

    it "can target DOM elements outside the parent sections as long as properly configured" do
      expect(subject.about.my_portal).to be_a(Tabasco::Portal)
      expect(subject.about.my_portal).to have_content("This is the portal")
      expect(subject.about.my_portal).to have_no_content("Another Portal Content")

      expect(subject.welcome_header.another_portal).to be_a(Tabasco::Portal)
      expect(subject.welcome_header.another_portal).to have_content("Another Portal Content")
      expect(subject.welcome_header.another_portal).to have_no_content("This is the portal")
    end

    it "cannot be used when they're not configured globally" do
      Tabasco.reset_configuration!

      expect { subject.about.my_portal }
        .to raise_error(Tabasco::Configuration::PortalNotConfigured)
    end
  end
end
