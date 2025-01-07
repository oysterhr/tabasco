# frozen_string_literal: true

module Tabasco
  class PreconditionNotMetError < Error; end

  class Container
    include Capybara::RSpecMatchers

    private_class_method :new # Use .load instead (or .visit for Page objects)

    def self.load(...)
      new(...).tap(&:ensure_loaded)
    end

    def self.attribute(attr_name)
      attributes << attr_name.to_sym
      attr_reader attributes.last
    end

    def self.attributes
      @attributes ||= []
    end

    def self.ensure_loaded(&block)
      @ensure_loaded_block = block
    end

    def self.ensure_loaded_block
      @ensure_loaded_block
    end

    # rubocop: disable Metrics/MethodLength
    def self.define_inline_section(name, klass = nil, inline_superclass:, &block)
      parent_name = self.name
      section_name = name.to_s.capitalize
      parent_attributes = attributes

      klass ||= Class.new(inline_superclass) do
        parent_attributes.each do |attr_name|
          attribute attr_name
        end

        def self.attribute(*)
          raise ArgumentError, "Attributes cannot be defined in anonymous sections. " \
                               "They inherit all arguments from parent pages/sections automatically."
        end

        # Simple and naive implementation for Anonymous classes
        # Will raise a Capybara error if the container cannot be found
        # Can be overridden in the inline block anyway
        ensure_loaded { container }

        class_eval <<~METHOD, __FILE__, __LINE__ + 1
          class << self
            def name
              "#{parent_name}|#{section_name}"
            end

            def inspect
              "Section(\#{name})"
            end

            alias_method :to_s, :inspect
          end

          def inspect
            "#<\#{self.class.inspect}:\#{object_id}>"
          end

          alias_method :to_s, :inspect
        METHOD

        class_eval(&block) if block
      end

      define_method(name) do |&block_argument|
        instance = instance_variable_get(:"@#{name}")
        unless instance
          inherited_attributes = self.class.attributes.each_with_object({}) do |attr_name, hash|
            hash[attr_name] = public_send(attr_name)
          end

          # Filter attributes to only include those defined in the explicit class
          filtered_attributes = inherited_attributes.slice(*klass.attributes)

          instance = klass.load(**filtered_attributes)
          instance_variable_set(:"@#{name}", instance)
        end

        block_argument&.call(instance)
        instance
      end
    end
    # rubocop: enable Metrics/MethodLength

    # Automatically adds a private precondition method for any has_X? query method added.
    # If a method named `has_<something>?` is defined, we will create a corresponding
    # `has_<something>!` method.
    #
    # The `has_X!` method will call the original `has_X?` method and raise a `PreconditionNotMetError`
    # if the result is not truthy.
    def self.method_added(method_name)
      method_name = method_name.to_s

      return unless method_name.start_with?("has_") && method_name.end_with?("?")

      bang_method_name = method_name.to_s.sub("?", "!")

      return if instance_methods.include?(bang_method_name.to_sym)

      original_method = instance_method(method_name)

      define_method(bang_method_name) do |*args, **kwargs, &block|
        result = original_method.bind_call(self, *args, **kwargs, &block)

        return result if result

        raise(
          PreconditionNotMetError,
          "#{bang_method_name}: Expected #{method_name} to return truthy, but it returned #{result.inspect}",
        )
      end

      # We don't want to expose the bang method to the outside world
      private bang_method_name

      super
    end

    def initialize(**kwargs)
      self.class.attributes.each do |attr_name|
        instance_variable_set(:"@#{attr_name}", kwargs[attr_name])
      end

      # raise an error if any of the attributes are not defined in the constructor
      unknown_attributes = kwargs.keys - self.class.attributes
      unless unknown_attributes.empty?
        raise ArgumentError, "Unknown attribute(s) passed to #{self.class}: #{unknown_attributes}"
      end

      # raise an error if any of the attributes are not defined in the constructor
      missing_attributes = self.class.attributes - kwargs.keys
      return if missing_attributes.empty?

      raise ArgumentError, "Missing attribute(s) passed to #{self.class}: #{missing_attributes}"
    end

    # Instance method to call the stored block
    def ensure_loaded
      unless self.class.ensure_loaded_block
        raise "Subclasses of Tabasco::Section must define how to check whether your " \
              "content has loaded with the ensure_loaded { ... } DSL method."

      end

      instance_exec(&self.class.ensure_loaded_block)
    end

    def container
      raise "Container not configured. Subclasses of Tabasco::Container must define a container method."
    end

    # Allows this page object to be used as subject of `expect` blocks:
    # expect(page_object_instance).to have_content
    #
    # And narrows any node dom finding operations to the container wrapper
    (Capybara::Session::NODE_METHODS + [:within]).each do |method|
      class_eval <<~METHOD, __FILE__, __LINE__ + 1
        def #{method}(...)                           # def find(...)
          wrapping { Capybara.current_session.#{method}(...) }      #  wrapping { Capybara.current_session.find(...) }
        end                                          # end
      METHOD
    end

    # Allows section objects to be used as arguments of Capybara::Session#within
    alias_method :to_capybara_node, :container

    private

    def wrapping
      return yield if already_wrapped?

      result = nil
      Capybara.current_session.within(container) { result = yield }

      result
    end

    def already_wrapped?
      own_wrapper_path = container.path

      Capybara.current_session.send(:scopes).any? { |el| el&.path&.start_with?(own_wrapper_path) }
    end
  end
end
