# frozen_string_literal: true

RSpec.describe Tabasco::Section::EnsureLoaded do
  let(:dummy_class) do
    Class.new do
      include Tabasco::Section::EnsureLoaded

      def initialize(loaded, container = nil)
        @loaded = loaded
        @container = container
      end

      def loaded?
        @loaded
      end

      attr_reader :container
    end
  end

  describe ".ensure_loaded" do
    it "stores the block to be used for checking if content is loaded" do
      dummy_class.ensure_loaded { loaded? }
      expect(dummy_class.ensure_loaded_block).to be_a(Proc)
    end
  end

  describe "#ensure_loaded" do
    context "when ensure_loaded block is defined" do
      before do
        dummy_class.ensure_loaded { loaded? }
      end

      it "does not raise an error if the block evaluates to true and the container is found" do
        instance = dummy_class.new(true, double("dummy container"))
        expect { instance.ensure_loaded }.not_to raise_error
      end

      it "raises PreconditionNotMetError if the block evaluates to false" do
        instance = dummy_class.new(false, double("dummy container"))
        expect { instance.ensure_loaded }.to raise_error(Tabasco::PreconditionNotMetError)
      end

      it "raises PreconditionNotMetError if the block evaluates to true but the container is not found" do
        instance = dummy_class.new(false, nil)
        expect { instance.ensure_loaded }.to raise_error(Tabasco::PreconditionNotMetError)
      end
    end

    context "when ensure_loaded block is not defined" do
      it "raises an error indicating the block must be defined" do
        instance = dummy_class.new(true, double("dummy container"))
        expect do
          instance.ensure_loaded
        end.to raise_error(RuntimeError, /must define how to check whether their content has loaded/)
      end
    end

    context "when ensure_loaded block raises an error" do
      it "propagates the error" do
        dummy_class.ensure_loaded { raise "Some error" }
        instance = dummy_class.new(true, double("dummy container"))
        expect { instance.ensure_loaded }.to raise_error(RuntimeError, "Some error")
      end
    end
  end
end
