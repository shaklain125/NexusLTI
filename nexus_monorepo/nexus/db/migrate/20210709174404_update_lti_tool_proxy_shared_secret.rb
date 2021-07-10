class UpdateLtiToolProxySharedSecret < ActiveRecord::Migration
  def change
    change_column :lti_tools, :shared_secret, :text, limit: nil
  end
end
