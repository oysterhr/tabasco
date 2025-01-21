# frozen_string_literal: true

module Tabasco
  class Configuration
    def initialize
      @portals = {}
    end

    def dsl
      @dsl ||= DSL.new(self)
    end

    def portal(name)
      name = name&.to_sym

      return @portals[name] if @portals.key?(name)

      message = <<~ERR
        Portal #{name.inspect} is not configured. Use Tabasco.configure to declare the acceptable
        portals. Refer to the README document for more information.
      ERR

      raise PortalNotConfiguredError, message
    end

    class DSL
      attr_reader :configuration

      def initialize(configuration)
        @configuration = configuration
      end

      # Declare portal elements your tests are allowed to use, with their related test_ids
      # This is a global configuration as a way to centralize and make it difficult to abuse
      # the usage of portals, since they ignore completely the automatic scoping of
      # Capybara's finders that Tabasco provides.
      #
      # Tabasco.configure do |config|
      #   # will locate data-testid="toast_message" anywhere in the DOM
      #   config.portal(:toast_message)
      #
      #   # As usual, the test_id can be overridden
      #   config.portal(:datepicker, test_id: :react_datepicker)
      #
      #   # And you can provide concrete subclass of Tabasco::Section class
      #   config.portal(:datepicker, MyDatepicker)
      # end
      def portal(name, klass = nil, test_id: nil)
        name = name.to_sym
        test_id ||= name

        if portals.key?(name)
          raise PortalAlreadyConfiguredError,
            "The portal #{name.inspect} is already defined"
        end

        portals[name] = {klass:, test_id:}

        nil
      end

      private

      def portals = configuration.instance_variable_get(:@portals)
    end
  end
end
