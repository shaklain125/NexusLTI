class CreateLtiLaunches < ActiveRecord::Migration
  def change
    create_table :lti_launches do |t|
      t.string :lti_tool_id
      t.string :nonce
      t.text :message
      t.timestamps
    end
  end
end
