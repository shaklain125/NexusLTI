class AddLtiRegistrationCorrelationId < ActiveRecord::Migration
  def change
    add_index :lti_registrations, :correlation_id, :unique => true
  end
end
