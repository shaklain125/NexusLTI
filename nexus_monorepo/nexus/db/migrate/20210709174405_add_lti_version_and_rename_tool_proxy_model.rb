class AddLtiVersionAndRenameToolProxyModel < ActiveRecord::Migration
  def change
    reversible do |dir|
      dir.up do
        #set lti_version to LTI-2p0
        execute <<-SQL
        UPDATE lti_tools SET lti_version = 'LTI-2p0';
        SQL
      end

      dir.down do
        #lti_version will get dropped so no need to do anything
      end
    end

  end
end
