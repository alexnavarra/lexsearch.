class AddSchedulingToCards < ActiveRecord::Migration[8.1]
  def change
    # SM-2 state; due_at nil means the card was never shown
    change_table :cards, bulk: true do |t|
      t.float :ease, null: false, default: 2.5
      t.integer :interval_days, null: false, default: 0
      t.integer :repetitions, null: false, default: 0
      t.datetime :due_at
      t.index :due_at
    end
  end
end
