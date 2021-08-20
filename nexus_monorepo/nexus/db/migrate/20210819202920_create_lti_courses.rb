class CreateLtiCourses < ActiveRecord::Migration
  def change
    create_table :lti_courses do |t|
      t.string :source
      t.string :course_id
      t.timestamps
    end
  end
end
