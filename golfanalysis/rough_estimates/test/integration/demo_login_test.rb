require "test_helper"

class DemoLoginTest < ActionDispatch::IntegrationTest
  test "GET /demo logs the visitor in as the demo account" do
    DemoData.seed!

    get demo_path
    assert_redirected_to root_path
    follow_redirect!
    assert_match DemoData::EMAIL, response.body
  end

  test "GET /demo without a demo account sends visitors to log in instead" do
    get demo_path
    assert_redirected_to login_path
  end
end
