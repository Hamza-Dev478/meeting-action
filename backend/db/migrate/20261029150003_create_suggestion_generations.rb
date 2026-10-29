class CreateSuggestionGenerations < ActiveRecord::Migration[8.1]
  def change
    create_table :suggestion_generations do |t|
      t.references :meeting, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "running"
      t.string :provider, null: false
      t.string :model
      t.string :prompt_version, null: false
      t.string :error_code
      t.string :error_message
      t.integer :suggestion_count, null: false, default: 0
      t.integer :rejected_count, null: false, default: 0
      # Per-item rejections and cleared fields from response validation.
      t.jsonb :validation_report, null: false, default: {}
      # Raw provider text (truncated) kept for diagnosing validation failures.
      t.text :raw_response
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
    end

    add_check_constraint :suggestion_generations,
      "status IN ('running', 'succeeded', 'failed')",
      name: "suggestion_generations_status_check"

    # At most one in-flight generation per meeting, enforced by PostgreSQL.
    add_index :suggestion_generations, :meeting_id,
      unique: true,
      where: "status = 'running'",
      name: "index_suggestion_generations_one_running_per_meeting"
  end
end
