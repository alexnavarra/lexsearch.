class SearchesController < ApplicationController
  def show
    @query = params[:q].to_s
    @filters = params.permit(:topic, :kind, :language).to_h
    @results = VectorSearch.new(@query, filters: @filters).call
  rescue Embeddings::Error => e
    @results = []
    flash.now[:alert] = "Embeddings недоступны: #{e.message}"
  end
end
