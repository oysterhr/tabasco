# frozen_string_literal: true

module Tabasco
  class Section
    module EnsureLoaded
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def ensure_loaded(&block)
          @ensure_loaded_block = block
        end

        def ensure_loaded_block
          @ensure_loaded_block
        end
      end

      # Instance method to call the stored block
      def ensure_loaded
        unless self.class.ensure_loaded_block
          raise "Page and section objects must define how to check whether their " \
                "content has loaded with the ensure_loaded { ... } DSL method."

        end

        return if instance_exec(&self.class.ensure_loaded_block) && container

        raise PreconditionNotMetError
      end
    end
  end
end
