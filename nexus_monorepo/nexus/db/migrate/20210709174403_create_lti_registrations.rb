class CreateLtiRegistrations < ActiveRecord::Migration
  def change
    create_table :lti_registrations do |t|
      t.string :uuid
      t.text :registration_request_params
      t.text :tool_proxy_json
      t.string :workflow_state
      t.timestamps
      t.integer :lti_tool_id
      t.text :correlation_id
    end
  end
end
