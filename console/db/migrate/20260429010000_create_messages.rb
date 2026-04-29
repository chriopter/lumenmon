class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.string :agent_id, null: false
      t.string :mail_from, null: false, default: "unknown"
      t.string :mail_to, null: false, default: ""
      t.string :subject, null: false, default: "(no subject)"
      t.text :body
      t.text :raw_content
      t.datetime :received_at, null: false
      t.boolean :read, null: false, default: false

      t.timestamps
    end

    add_index :messages, [:agent_id, :received_at]
    add_index :messages, :read
  end
end
