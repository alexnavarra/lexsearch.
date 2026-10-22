class AddPagesToChunks < ActiveRecord::Migration[8.1]
  def change
    add_column :chunks, :page_from, :integer
    add_column :chunks, :page_to, :integer
  end
end
