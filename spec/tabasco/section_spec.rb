# frozen_string_literal: true

RSpec.describe Tabasco::Section do
  let(:section_klass) do
    Class.new(described_class) do
      container_test_id :section_container

      ensure_loaded { true }

      attribute :user
      attribute :customer_id

      section :lorem
      section :ipsum do
        section :dolor
      end
    end
  end

  before do
    Capybara.current_session.visit("section_spec.html")
  end

  it "can access sections with dot notation" do
    section = section_klass.load(user: "John", customer_id: 123)

    expect(section.lorem).to be_a(described_class)
    expect(section.ipsum.dolor).to be_a(described_class)
  end

  it "yields the section instance itself if provided with a block" do
    section = section_klass.load(user: "John", customer_id: 123)
    block_called = false

    section.lorem do |lorem|
      block_called = true
      expect(lorem).to eq(section.lorem)
    end

    expect(block_called).to be true
  end

  describe "#_handle" do
    it "can be omitted" do
      section = section_klass.load(user: "John", customer_id: 123)

      expect(section._handle).to be_nil
    end

    it "can be passed when loading the section" do
      section = section_klass.load("test-handle", user: "John", customer_id: 123)

      expect(section._handle).to eq("test-handle")
    end

    it "is set on subclasses" do
      section = section_klass.load(user: "John", customer_id: 123)

      expect(section.lorem._handle).to eq(:lorem)
      expect(section.ipsum._handle).to eq(:ipsum)
    end
  end

  describe "attributes DSL" do
    it "allows instances of the section to receive attributes" do
      section = section_klass.load(user: "John", customer_id: 123)

      expect(section.user).to eq("John")
      expect(section.customer_id).to eq(123)
    end

    it "raises an error if wrong attributes are provided" do
      expect { section_klass.load(user: "John", wrong_attribute: 123) }
        .to raise_error(ArgumentError)
    end

    it "attributes must be explicitly passed" do
      expect { section_klass.load }
        .to raise_error(ArgumentError)
    end

    it "accepts explicit nil values" do
      section = section_klass.load(user: nil, customer_id: nil)

      expect(section.user).to be_nil
      expect(section.customer_id).to be_nil
    end

    it "propagates attributes to inline sections" do
      section = section_klass.load(user: "John", customer_id: 123)

      expect(section.lorem.user).to eq(section.user)
      expect(section.ipsum.dolor.customer_id).to eq(section.customer_id)
    end

    it "does not allow anonymous sections to declare arguments" do
      expect do
        Class.new(described_class) do
          attribute :user

          section :anonymous_section do
            attribute :customer
            attribute :user
          end
        end

        # TODO: create custom error
      end.to raise_error(ArgumentError, /Attributes cannot be defined in anonymous sections/)
    end

    it "only passes attributes to explicit classes if they define that attribute" do
      subclass = Class.new(Tabasco::Section) do
        container_test_id :lorem
        ensure_loaded { true }

        attribute :user
      end

      section_klass = Class.new(described_class) do
        container_test_id :section_container
        ensure_loaded { true }

        attribute :user
        attribute :customer

        section :subsection, subclass

        section :anonymous_subsection, test_id: :ipsum do
          ensure_loaded { true }
        end
      end

      section = section_klass.load(user: "John", customer: "Acme")

      expect(section.anonymous_subsection.user).to eq("John")
      expect(section.anonymous_subsection.customer).to eq("Acme")

      expect(section.subsection.user).to eq("John")
      expect { section.subsection.customer }.to raise_error(NoMethodError)
    end
  end

  describe "has<something>! precondition methods" do
    it "exposes a private precondition method for capybara has_X? query methods" do
      section = section_klass.load(user: "John", customer_id: 123)

      expect(section.methods).to include(:has_content?)
      expect(section.methods).to include(:has_link?)

      expect(section.private_methods).to include(:has_content!)
      expect(section.private_methods).to include(:has_link!)
    end

    it "automatically adds a private precondition method for any custom has_X? query method" do
      section = section_klass.load(user: "John", customer_id: 123)
      expect(section.private_methods).not_to include(:has_custom_query!)

      section_klass.class_eval do
        def has_custom_query?
          # Custom query logic
        end
      end

      expect(section.private_methods).to include(:has_custom_query!)
    end
  end
end
