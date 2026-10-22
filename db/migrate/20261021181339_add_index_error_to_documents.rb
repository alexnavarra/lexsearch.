class AddIndexErrorToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :index_error, :text
  end
end
