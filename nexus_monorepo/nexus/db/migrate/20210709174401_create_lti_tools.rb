class CreateLtiTools < ActiveRecord::Migration
  def change
    create_table :lti_tools do |t|
      t.string :uuid
      t.string :shared_secret
      t.text :tool_settings
      t.timestamps
      t.string :lti_version
    end
  end
end
