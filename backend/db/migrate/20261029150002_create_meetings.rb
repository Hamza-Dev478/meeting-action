class CreateMeetings < ActiveRecord::Migration[8.1]
  def change
    create_table :meetings do |t|
      t.references :organization, null: false, foreign_key: true, index: false
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :notes, null: false
      t.timestamps
    end
    # Every meeting query is scoped by organization and listed newest first.
    add_index :meetings, [ :organization_id, :created_at ]
  end
end
