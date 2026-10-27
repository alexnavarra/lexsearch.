class AddFromCacheToQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :questions, :from_cache, :boolean, default: false, null: false
  end
end
