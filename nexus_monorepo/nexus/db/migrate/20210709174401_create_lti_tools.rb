class CreateLtiTools < ActiveRecord::Migration
  def change
    create_table :lti_tools do |t|
      t.string :uuid
      t.text :shared_secret
      t.text :tool_settings
      t.string :lti_version
      t.timestamps
    end
  end
end
