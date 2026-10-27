class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Not Rails.cache directly: the test env has a null cache store, which never counts
  RATE_LIMIT_STORE = Rails.configuration.x.rate_limit_store || Rails.cache

  # Actions that call the LLM cost money: a per-IP limit, with a message instead of a bare 429
  def self.limit_llm_requests(to:, only:)
    rate_limit to:, within: 1.minute, only:, store: RATE_LIMIT_STORE,
               with: -> { redirect_back_or_to root_path, alert: "Слишком много запросов к LLM: подожди минуту." }
  end
end
