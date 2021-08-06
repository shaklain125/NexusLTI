class CreateLtiSessions < ActiveRecord::Migration
  def change
    create_table :lti_sessions do |t|
      t.string :lti_tool_id
      t.string :user_id
      t.timestamps
    end
  end
end
