# Resource handlers and all capabilities
LTI_RESOURCE_HANDLERS = LtiUtils::RHHelper.resource_handlers!.freeze
LTI_RH_ALL_CAPS = LtiUtils::RHHelper.all_caps!.freeze

# Clean up
LtiTool.clean_up!
LtiRegistration.clean_up!

# Cipher keys used to encrypt LTI token and config
LTI_CONFIG_SECRET = '8cb13f93bf4b9bd12846d08c8814755d35fea3ff491bf08a0bbf381fe9a80892703ee58b072c18acc376d72b0d42ad392e42c63309e46e3aff63b450c396520d'.freeze
LTI_TOKEN_SECRET = SecureRandom.hex(64).to_s.freeze

# Valid LMS Hosts. It is optional and can be left empty as launch validation exists.
LTI_VALID_LMS_ORIGIN_HOSTS = [
  '192.168.1.81'
].freeze

# Teacher LTI Permissions
# - The constants that state the first teacher refers to the teacher that creates a course.
#   Other teachers in the same course will be affected if permission is given to only the first teacher.
# - Managing only the current course suggests that the teacher will not be able to manage their other courses in the same session.
#   The teacher would need to navigate to the other courses separately in the LMS to be able to manage them in LTI.
# - Managing only the current assignment means that the teacher will only be able to do CRUD operations on a single assignment.
#   They will not be able to manage other assignments in the same session.

## Course deletion
LTI_TEACHER_ALLOW_COURSE_DELETE = true
LTI_ALLOW_ONLY_FIRST_TEACHER_COURSE_DELETE = true

## Management
LTI_TEACHER_MANAGE_ONLY_CURRENT_COURSE = false
LTI_TEACHER_MANAGE_ONLY_CURRENT_ASSIGNMENT = false

## Assignment CRUD operations
LTI_ALLOW_ONLY_FIRST_TEACHER_CREATE_ASSIGNMENT = false
LTI_ALLOW_ONLY_FIRST_TEACHER_EDIT_ASSIGNMENT = false
LTI_ALLOW_ONLY_FIRST_TEACHER_DELETE_ASSIGNMENT = false
