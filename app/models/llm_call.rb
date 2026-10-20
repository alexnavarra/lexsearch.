class LlmCall < ApplicationRecord
  enum :status, { ok: "ok", error: "error" }, validate: true

  validates :purpose, :provider, :model, presence: true
end
