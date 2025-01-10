# frozen_string_literal: true

RSpec.describe Tabasco do
  it "has a version number" do
    expect(Tabasco::VERSION).not_to be_nil
  end

  describe ".configure" do
    it "yields the configuration dsl" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class.configuration.dsl)
    end
  end

  describe ".configuration" do
    it "returns the configuration" do
      expect(described_class.configuration).to be_a(Tabasco::Configuration)
    end
  end
end
