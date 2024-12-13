# frozen_string_literal: true

RSpec.describe Oyster::Harbor do
  it "has a version number" do
    expect(Oyster::Harbor::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
