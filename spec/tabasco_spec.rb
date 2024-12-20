# frozen_string_literal: true

RSpec.describe Tabasco do
  it "has a version number" do
    expect(Tabasco::VERSION).not_to be_nil
  end

  describe ".configure" do
    it "yields the configuration dsl" do
      expect { |b| Tabasco.configure(&b) }.to yield_with_args(Tabasco.configuration.dsl)
    end
  end

  describe ".configuration" do
    it "returns the configuration" do
      expect(Tabasco.configuration).to be_a(Tabasco::Configuration)
    end
  end
end
