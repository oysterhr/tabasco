# frozen_string_literal: true

RSpec.describe Tabasco::Configuration do
  subject(:configuration) { described_class.new }

  it "defines sensitive defaults" do
    expect(configuration.portal).to be_nil
  end

  describe "#dsl" do
    subject { configuration.dsl }

    it "exposes a dsl for writing configuration" do
      is_expected.to be_a(Tabasco::Configuration::DSL)
      
      expect(subject.configuration).to eq(configuration)
    end

    describe "#portal" do
      it "stores the portal block in the configuration object" do
        block = -> { "lorem" }
        subject.portal(&block)
        expect(configuration.portal).to be block
      end
    end
  end
end
