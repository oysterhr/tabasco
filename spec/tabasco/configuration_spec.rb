# frozen_string_literal: true

RSpec.describe Tabasco::Configuration do
  subject(:configuration) { described_class.new }
  let(:dsl) { configuration.dsl }

  it "exposes a dsl for writing configuration" do
    expect(dsl).to be_a(Tabasco::Configuration::DSL)

    expect(dsl.configuration).to eq(configuration)
  end

  describe "portal configuration" do
    it "can be defined using the DSL and read from the configuration object" do
      dsl.portal(:my_portal)
    
      expect(configuration.portal(:my_portal)).to eq(test_id: :my_portal)
    end

    it "accepts a test_id override" do
      dsl.portal(:my_portal, test_id: :lorem_ipsum)
      expect(configuration.portal(:my_portal)).to eq(test_id: :lorem_ipsum)
    end

    it "allows the definition of multiple independent portals" do
      dsl.portal(:my_portal, test_id: :lorem_ipsum)
      dsl.portal(:datepicker, test_id: :the_date_picker)
      dsl.portal(:toast_message)

      expect(configuration.portal(:my_portal)).to eq(test_id: :lorem_ipsum)
      expect(configuration.portal(:datepicker)).to eq(test_id: :the_date_picker)
      expect(configuration.portal(:toast_message)).to eq(test_id: :toast_message)
    end

    it "raises an error when trying to read a portal that has not been defined" do
      expect {
        configuration.portal(:my_portal)
      }.to raise_error(Tabasco::Configuration::PortalNotConfigured)
    end

    it "raises an error when trying to define a portal with the same name twice" do
      dsl.portal(:my_portal)

      expect {
        dsl.portal(:my_portal)
      }.to raise_error(Tabasco::Configuration::Error, "The portal :my_portal is already defined")
    end
  end
end
