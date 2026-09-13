require "test_helper"

class AnalysisFlowTest < ActionDispatch::IntegrationTest
  test "requires login" do
    get progress_path
    assert_redirected_to login_path
  end

  test "renders with the current user's per-shot data embedded, even with zero shots" do
    user = User.create!(email: "golfer@example.com", password: "password123")
    post login_path, params: { email: "golfer@example.com", password: "password123" }

    get progress_path
    assert_response :success
    assert_match "const DATA = ", response.body
    assert_match(/"rows":\[\]/, response.body)
  end

  test "embeds real shot data for the demo account" do
    DemoData.seed!
    post login_path, params: { email: DemoData::EMAIL, password: DemoData::PASSWORD }

    get progress_path
    assert_response :success
    assert_match(/"clubs":\["\w/, response.body)
    refute_match(/"rows":\[\]/, response.body)
  end
end
