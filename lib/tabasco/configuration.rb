# frozen_string_literal: true

module Tabasco
  class Configuration
    attr_reader :portal

    def dsl
      @dsl ||= DSL.new(self)
    end

    class DSL
      attr_reader :configuration

      def initialize(configuration)
        @configuration = configuration
      end
      
      # Define a proc that will be used to find the default portal element in the DOM.
      # example:
      #
      # Tabasco.configure do |config|
      #   config.portal do
      #     find("[data-floating-ui-portal]")
      #   end
      # end
      #
      # Right now we only support a single portal element, but we could easily extend this
      # to support multiple named portals.
      def portal(&block)
        configuration.instance_variable_set(:@portal, block)
      end
    end
  end
end