# frozen_string_literal: true

require_relative "lib/tabasco/version"

Gem::Specification.new do |spec|
  spec.name = "tabasco"
  spec.version = Tabasco::VERSION
  spec.authors = ["Oyster HR, Inc. Engineers"]
  spec.email = ["developers@oysterhr.com"]

  summary = <<~SUMMARY
    Tabasco is an experimental, opinionated page-object framework designed to anchor your
    system tests in stability, reducing flakiness and simplifying navigation.
  SUMMARY
  spec.summary = summary
  spec.description = summary
  spec.homepage = "https://github.com/oysterhr/tabasco"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/oysterhr/tabasco"
  spec.metadata["changelog_uri"] = "https://github.com/oysterhr/tabasco/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 3.2"
  spec.add_dependency "capybara", "~> 3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rack"
  spec.add_development_dependency "rubocop-capybara"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "rubocop-rspec"
end
