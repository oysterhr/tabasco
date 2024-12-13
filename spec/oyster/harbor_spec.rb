# frozen_string_literal: true

RSpec.describe Oyster::Harbor do
  it "has a version number" do
    expect(Oyster::Harbor::VERSION).not_to be_nil
  end
end
