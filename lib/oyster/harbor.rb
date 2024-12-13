# frozen_string_literal: true
require "capybara/dsl"
require "capybara/rspec/matchers"

require_relative "harbor/version"
require_relative "harbor/page"

module Oyster
  module Harbor
    class Error < StandardError; end
  end
end
