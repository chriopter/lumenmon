require "test_helper"

class ApiCsrfProtectionTest < ActionDispatch::IntegrationTest
  setup do
    @allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @allow_forgery_protection
  end

  test "state changing api requests require a csrf token" do
    post "/api/invites/create/full"

    assert_response :unprocessable_content
  end
end
