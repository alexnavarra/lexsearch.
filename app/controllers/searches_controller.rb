class SearchesController < ApplicationController
  MODES = { "vector" => VectorSearch, "fulltext" => FulltextSearch }.freeze

  def show
    @query = params[:q].to_s
    @mode = MODES.key?(params[:mode]) ? params[:mode] : "vector"
    @filters = params.permit(:topic, :kind, :language).to_h
    @results = MODES.fetch(@mode).new(@query, filters: @filters).call
  rescue Embeddings::Error => e
    @results = []
    flash.now[:alert] = "Embeddings недоступны: #{e.message}"
  end
end
