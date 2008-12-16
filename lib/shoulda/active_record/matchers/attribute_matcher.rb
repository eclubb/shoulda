module ThoughtBot # :nodoc:
  module Shoulda # :nodoc:
    module ActiveRecord # :nodoc:
      module Matchers # :nodoc:

        class AllowValueMatcher
          include Helpers

          def initialize(value)
            @value = value
          end

          def for(attribute)
            @attribute = attribute
            self
          end

          def with_message(message)
            @expected_message = message if message
            self
          end

          def matches?(instance)
            @instance = instance
            @expected_message ||= :invalid
            if Symbol === @expected_message
              @expected_message = default_error_message(@expected_message)
            end
            @instance.send("#{@attribute}=", @value)
            !errors_match?
          end

          def failure_message
            "Did not expect #{expectation}, got error: #{@matched_error}"
          end

          def negative_failure_message
            "Expected #{expectation}, got #{error_description}"
          end

          def description
            if @value.nil?
              "allow #{@attribute} to be blank"
            else
              description = "have an attribute called #{@attribute}"
              description << " accepting value #{@value.inspect}"
              description << " without error #{@expected_message.inspect}"
              description
            end
          end

          private

          def errors_match?
            @instance.valid?
            @errors = @instance.errors.on(@attribute)
            @errors = [@errors] unless @errors.is_a?(Array)
            errors_match_regexp? || errors_match_string?
          end

          def errors_match_regexp?
            if Regexp === @expected_message
              @matched_error = @errors.detect { |e| e =~ @expected_message }
              !@matched_error.nil?
            else
              false
            end
          end

          def errors_match_string?
            if @errors.include?(@expected_message)
              @matched_error = @expected_message
              true
            else
              false
            end
          end

          def expectation
            "errors to include #{@expected_message.inspect} " <<
            "when #{@attribute} is set to #{@value.inspect}"
          end

          def error_description
            if @instance.errors.empty?
              "no errors"
            else
              "errors: #{pretty_error_messages(@instance)}"
            end
          end
        end

        class RequireUniqueAttributeMatcher
          include Helpers

          def initialize(attribute)
            @attribute = attribute
          end

          def scoped_to(*scopes)
            @scopes = [*scopes].flatten
            self
          end

          def with_message(message)
            @expected_message = message
            self
          end

          def description
            result = "require unique value for #{@attribute}"
            result << " scoped to #{@scopes.join(', ')}" unless @scopes.blank?
          end

          def failure_message
            if @allow_value
              @allow_value.failure_message
            else
              if @existing
                if @reject_value
                  @reject_value.negative_failure_message
                else
                  @failed_expectation
                end
              else
                "Can't find first #{class_name}"
              end
            end
          end

          def negative_failure_message
            if @allow_value
              @allow_value.negative_failure_message
            else
              if @reject_value
                @reject_value.failure_message
              else
                failure_message
              end
            end
          end

          def matches?(subject)
            @subject = subject
            @expected_message ||= :taken
            if Symbol === @expected_message
              @expected_message = default_error_message(@expected_message)
            end
            find_existing && 
              set_scoped_attributes && 
              validate_attribute &&
              validate_after_scope_change
          end

          private

          def find_existing
            @existing = @subject.class.find(:first)
          end

          def class_name
            @subject.class.name
          end

          def set_scoped_attributes
            unless @scopes.blank?
              @scopes.each do |scope|
                setter = :"#{scope}="
                unless @subject.respond_to?(setter)
                  @failed_expectation = 
                    "#{class_name} doesn't seem to have a #{scope} attribute."
                  return false
                end
                @subject.send("#{scope}=", @existing.send(scope))
              end
            end
            true
          end

          def validate_attribute
            @reject_value = AllowValueMatcher.
              new(existing_value).
              for(@attribute).
              with_message(@expected_message)
            !@reject_value.matches?(@subject)
          end

          # TODO:  There is a chance that we could change the scoped field
          # to a value that's already taken.  An alternative implementation
          # could actually find all values for scope and create a unique
          def validate_after_scope_change
            unless @scopes.blank?
              @scopes.each do |scope|
                previous_value = @existing.send(scope)

                # Assume the scope is a foreign key if the field is nil
                previous_value ||= 0

                next_value = previous_value.next

                @subject.send("#{scope}=", next_value)

                @allow_value = AllowValueMatcher.
                  new(existing_value).
                  for(@attribute).
                  with_message(@expected_message)
                return false unless @allow_value.matches?(@subject)
              end
            end
            true
          end

          def existing_value
            @existing.send(@attribute)
          end
        end

        def allow_value(value)
          AllowValueMatcher.new(value)
        end

        def allow_blank_for(attr)
          AllowValueMatcher.
            new(nil).
            for(attr).
            with_message(:blank)
        end

        def require_unique_attribute(attr)
          RequireUniqueAttributeMatcher.new(attr)
        end
      end
    end
  end
end
