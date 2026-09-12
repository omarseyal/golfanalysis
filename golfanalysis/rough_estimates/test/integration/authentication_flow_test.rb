require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "signup logs the user in and redirects to the dashboard" do
    assert_difference -> { User.count } do
      post signup_path, params: { user: { email: "new@example.com", password: "password123" } }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_match "Log out", response.body
  end

  test "root redirects to login when signed out" do
    get root_path
    assert_redirected_to login_path
  end

  test "login then logout" do
    user = User.create!(email: "golfer@example.com", password: "password123")

    post login_path, params: { email: "golfer@example.com", password: "password123" }
    assert_redirected_to root_path

    delete logout_path
    assert_redirected_to login_path

    get root_path
    assert_redirected_to login_path
  end

  test "wrong password re-renders the login form" do
    User.create!(email: "golfer@example.com", password: "password123")

    post login_path, params: { email: "golfer@example.com", password: "wrong" }
    assert_response :unprocessable_entity
  end
end
