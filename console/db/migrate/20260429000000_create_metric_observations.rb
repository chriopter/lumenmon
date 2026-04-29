class CreateMetricObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :metric_observations do |t|
      t.string :agent_id, null: false
      t.string :metric_name, null: false
      t.text :value
      t.string :data_type, null: false, default: "TEXT"
      t.integer :interval, null: false, default: 60
      t.float :min
      t.float :max
      t.float :warn_min
      t.float :warn_max
      t.datetime :observed_at, null: false

      t.timestamps
    end

    add_index :metric_observations,
      [:agent_id, :metric_name, :observed_at],
      name: "index_metric_observations_on_metric_time"
    add_index :metric_observations, :observed_at
  end
end
