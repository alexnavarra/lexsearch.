# Search page: the form plus one Turbo Frame per method; each frame loads from SearchResultsController
class SearchesController < ApplicationController
  def show
    @query = params[:q].to_s
    @filters = params.permit(:topic, :kind, :language).to_h
  end
end
