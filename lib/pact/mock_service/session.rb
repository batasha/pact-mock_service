require 'pact/mock_service/interactions/expected_interactions'
require 'pact/mock_service/interactions/actual_interactions'
require 'pact/mock_service/interactions/verified_interactions'
require 'pact/mock_service/interaction_decorator'
require 'pact/mock_service/interactions/interaction_diff_message'

module Pact
  module MockService

    class AlmostDuplicateInteractionError < StandardError; end

    class Session

      attr_reader :expected_interactions, :actual_interactions, :verified_interactions, :consumer_contract_details, :logger

      def initialize options
        @logger = options[:logger]
        @consumer_contract_details = {
        pact_dir: options[:pact_dir],
        consumer: {name: options[:consumer]},
        provider: {name: options[:provider]},
        interactions: verified_interactions,
        pact_specification_version: options[:pact_specification_version],
        pactfile_write_mode: options[:pactfile_write_mode],
        pactfile: options[:file_uri]
        }
        @expected_interactions = if @consumer_contract_details[:pactfile_write_mode] == "read"
          load_interactions_from_file
        else
          Interactions::ExpectedInteractions.new
        end
        @actual_interactions = Interactions::ActualInteractions.new
        @verified_interactions = Interactions::VerifiedInteractions.new
      end

      def load_interactions_from_file
        expected_interactions = Interactions::ExpectedInteractions.new
        interactions_from_file = Pact::ConsumerContract.from_uri(@consumer_contract_details[:pactfile]).interactions
        interactions_from_file.each do | interaction |
          expected_interactions << interaction
        end
        expected_interactions
      end

      def set_expected_interactions interactions
        clear_expected_and_actual_interactions
        interactions.each do | interaction |
          add_expected_interaction interaction
        end
      end

      def clear_expected_and_actual_interactions
        expected_interactions.clear
        actual_interactions.clear
      end

      def add_expected_interaction interaction
        if (previous_interaction = interaction_already_verified_with_same_description_and_provider_state_but_not_equal(interaction))
          handle_almost_duplicate_interaction previous_interaction, interaction
        else
          really_add_expected_interaction interaction
        end
      end

      private

      def really_add_expected_interaction interaction
        expected_interactions << interaction
        logger.info "Registered expected interaction #{interaction.request.method_and_path}"
        logger.debug JSON.pretty_generate InteractionDecorator.new(interaction)
      end

      def handle_almost_duplicate_interaction previous_interaction, interaction
        message = Interactions::InteractionDiffMessage.new(previous_interaction, interaction).to_s
        logger.error message
        raise AlmostDuplicateInteractionError, message
      end

      def interaction_already_verified_with_same_description_and_provider_state_but_not_equal interaction
        other = verified_interactions.find_matching_description_and_provider_state interaction
        other && other != interaction ? other : nil
      end

    end
  end
end
