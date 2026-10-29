class CreateSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :suggestions do |t|
      t.references :meeting, null: false, foreign_key: true, index: false
      t.references :suggestion_generation, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.text :description, null: false
      t.string :owner
      t.date :due_date
      # Exact excerpt from the meeting notes that supports this suggestion.
      t.text :source_quote, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :suggestions, [ :meeting_id, :status ]
    add_check_constraint :suggestions,
      "status IN ('pending', 'accepted', 'dismissed', 'superseded')",
      name: "suggestions_status_check"
  end
end
