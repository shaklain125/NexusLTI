LtiUtils::Setup.configure Module do |config, setup|

  # Resource handlers and all capabilities
  config.resource_handler = {
    all: LtiUtils::RHHelper.resource_handlers!,
    all_caps: LtiUtils::RHHelper.all_caps!
  }

  # Clean up
  setup.clean_up!

  # Cipher keys used to encrypt LTI session token and config
  config.config_secret = '8cb13f93bf4b9bd12846d08c8814755d35fea3ff491bf08a0bbf381fe9a80892703ee58b072c18acc376d72b0d42ad392e42c63309e46e3aff63b450c396520d'
  config.token_secret = SecureRandom.hex(64)

  # Valid LMS Hosts. It is optional and can be left empty as launch validation exists.
  config.lms_hosts = [
    '192.168.1.81'
  ]

  ## Management permissions for teachers
  # - Managing only the current course suggests that the teacher will not be able to manage their other courses in the same session.
  #   The teacher would need to navigate to the other courses separately in the LMS to be able to manage them in LTI.
  # - Managing only the current assignment means that the teacher will only be able to do CRUD operations on a single assignment.
  config.management = {
    delete_course: true,
    only_current_course: false,
    only_current_assignment: false
  }

  ## First teacher only, permissions. Allow only the first teacher to do tasks below.
  # - The first teacher is the teacher that creates a course.
  #   Other teachers in the same course will be affected if permission is given to only the first teacher.
  config.first_teacher_only = {
    delete_course: true, # depends on 'management.delete_course' permission
    create_assignment: false,
    edit_assignment: false,
    delete_assignment: false
  }

end
