class CreateAgentProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_profiles do |t|
      t.string :agent_id, null: false
      t.string :display_name
      t.datetime :invited_at

      t.timestamps
    end

    add_index :agent_profiles, :agent_id, unique: true
  end
end
