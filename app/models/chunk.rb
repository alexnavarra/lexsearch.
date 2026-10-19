class Chunk < ApplicationRecord
  belongs_to :document

  validates :position, :section_ref, :content, :token_count, :topic, :language, presence: true
end
