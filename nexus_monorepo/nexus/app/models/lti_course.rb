class LtiCourse < ActiveRecord::Base
  validates_presence_of :source
  belongs_to :course
end
