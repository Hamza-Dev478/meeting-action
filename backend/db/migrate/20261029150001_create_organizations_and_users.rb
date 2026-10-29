class CreateOrganizationsAndUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :organizations, :name, unique: true

    create_table :users do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      # SHA-256 digest of the development bearer token; the raw token is never stored.
      t.string :api_token_digest
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :api_token_digest, unique: true
  end
end
