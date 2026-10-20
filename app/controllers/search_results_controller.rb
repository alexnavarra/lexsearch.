# Results of one search method, rendered into its Turbo Frame on the search page
class SearchResultsController < ApplicationController
  MODES = %w[vector fulltext hybrid].freeze

  def index
    @mode = MODES.include?(params[:mode]) ? params[:mode] : "hybrid"
    @query = params[:q].to_s
    filters = params.permit(:topic, :kind, :language).to_h
    @results =
      case @mode
      when "vector" then VectorSearch.new(@query, filters:).call
      when "fulltext" then FulltextSearch.new(@query, filters:).call
      else HybridSearch.new(@query, filters:, strategy: params[:strategy] == "sql" ? :sql : :ruby).call
      end
  rescue Embeddings::Error => e
    @results = []
    @error = "Embeddings недоступны: #{e.message}"
  end
end
