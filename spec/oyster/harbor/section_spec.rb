# frozen_string_literal: true

RSpec.describe Oyster::Harbor::Section do
  let(:section_klass) do
    Class.new(described_class) do
      container_test_id "root"

      attribute :user
      attribute :customer_id

      # Override so we can do unit tests without any DOM dependency
      ensure_loaded { true }

      section :lorem do
        ensure_loaded { true }
      end

      section :ipsum do
        ensure_loaded { true }

        section :dolor do
          ensure_loaded { true }
        end
      end
    end
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
      subclass = Class.new(Oyster::Harbor::Section) do
        ensure_loaded { true }

        attribute :user
        section :subsub
      end

      section_klass = Class.new(described_class) do
        ensure_loaded { true }

        attribute :user
        attribute :customer

        section :subsection, subclass
        section :anonymous_subsection do
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
