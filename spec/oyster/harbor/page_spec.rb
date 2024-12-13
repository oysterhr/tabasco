# frozen_string_literal: true

RSpec.describe Oyster::Harbor::Page do
  subject { page_klass.visit }

  let(:page) { Capybara.current_session }
  let(:page_url) { "test_page.html" }
  let(:contact_section_klass) { nil }

  let(:page_klass) do
    contact_section_klass_value = contact_section_klass
    page_url_value = page_url

    Class.new(described_class) do
      url page_url_value
      container_test_id "root" # do we want containers on pages?

      ensure_loaded { has_content!("Welcome to the Testing Demo Page") }

      section :welcome_header
      section :top_menu
      section :about do
        section :first_article
        section :second_article
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

  describe "providing defined section classes" do
    let(:contact_section_klass) do
      Class.new(Oyster::Harbor::Section) do
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

  context "when the page fails to load properly" do
    let(:page_url) { "oops_not_found.html" }

    it "raises an expectation error when trying to use the page object" do
      # TODO: wrap with Oyster::Harbor:: custom error class and improve error message
      expect { subject }
        .to raise_error(Capybara::ElementNotFound, "Unable to find css \"[data-testid='root']\"")
    end
  end

  it "raises Capybara::ElementNotFound when trying to interact with sections not rendered in the page" do
    # TODO: wrap with Oyster::Harbor:: custom error class and improve error message
    expect { subject.non_existing_section }
      .to raise_error(Capybara::ElementNotFound, "Unable to find css \"[data-testid='non-existing-section']\"")
  end

  context "when the ensure_loaded block for a section fails" do
    it "raises Oyster::Harbor::PreconditionNotMetError" do
      # TODO: error message can definitely be improved
      expect { subject.does_not_load_properly }
        .to raise_error(
          Oyster::Harbor::PreconditionNotMetError,
          "has_content!: Expected has_content? to return truthy, but it returned false",
        )
    end
  end
end
