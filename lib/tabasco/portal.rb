# frozen_string_literal: true

require_relative "container"

module Tabasco
  class PortalNotConfigured < ::Tabasco::Error; end

  class Portal < Container
    def container
      @container ||= begin
        self.class.assert_portal_configured!

        Capybara.current_session.instance_eval(
          &Tabasco.configuration.portal
        )
      end
    end

    def self.assert_portal_configured!
      return if Tabasco.configuration.portal

      message = <<~ERR
        Portal not configured, you must provide a block that fetches the default portal
        container using Tabasco.configure. Example:

        Tabasco.configure do |config|
          config.portal do
            find("[data-my-portal-container]")
          end
        end
      ERR

      raise PortalNotConfigured, message
    end
  end

  class Container
    def self.portal(name, klass = nil, &)
      Portal.assert_portal_configured!

      define_inline_section(name, klass, inline_superclass: Portal, &)
    end
  end
end
