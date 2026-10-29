class CreateActionItems < ActiveRecord::Migration[8.1]
  def change
    create_table :action_items do |t|
      t.references :meeting, null: false, foreign_key: true, index: false
      # One action per suggestion. This unique index is the duplicate-acceptance
      # invariant; application code only decides how to respond to it.
      t.references :suggestion, null: false, foreign_key: true, index: { unique: true }
      t.references :accepted_by, null: false, foreign_key: { to_table: :users }
      t.text :description, null: false
      t.string :owner
      t.date :due_date
      # Copied from the suggestion at acceptance time as provenance; never edited.
      t.text :source_quote, null: false
      t.datetime :completed_at
      t.timestamps
    end

    add_index :action_items, [ :meeting_id, :created_at ]
  end
end
