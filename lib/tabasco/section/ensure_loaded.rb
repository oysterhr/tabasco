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
          raise "Subclasses of Tabasco::Section must define how to check whether your " \
                "content has loaded with the ensure_loaded { ... } DSL method."

        end

        instance_exec(&self.class.ensure_loaded_block)
      end
    end
  end
end