class UpdateLtiToolIdType < ActiveRecord::Migration
  def change
    if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) &&
        ActiveRecord::Base.connection.instance_of?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
      change_column :lti_launches, :lti_tool_id, "bigint USING CAST(lti_tool_id AS bigint)"
      change_column :lti_registrations, :lti_tool_id, "bigint USING CAST(lti_tool_id AS bigint)"
    else
      change_column :lti_launches, :lti_tool_id, :integer, limit: 8
      change_column :lti_registrations, :lti_tool_id, :integer, limit: 8
    end
  end
end
