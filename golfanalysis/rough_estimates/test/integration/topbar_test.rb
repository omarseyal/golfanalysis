require "test_helper"

# Every signed-in page shares one header (shared/_topbar), and the Account
# menu links to the account page.
class TopbarTest < ActionDispatch::IntegrationTest
  setup do
    DemoData.seed!
    post login_path, params: { email: DemoData::EMAIL, password: DemoData::PASSWORD }
  end

  test "the dashboard, sessions, and account pages all use the shared header" do
    [ root_path, trackman_sessions_path, account_path ].each do |path|
      get path
      assert_response :success
      assert_select ".topbar #acctdrop a[href=?]", account_path, { text: /Account/ }, "no Account link on #{path}"
      assert_select ".topbar #nav", 1
      assert_select "nav.topbar .links", false, "old header on #{path}"
    end
  end

  test "off the dashboard, the Clubs menu links back into it" do
    get trackman_sessions_path
    assert_select "#clubdrop a[href^=?]", "/#/club/"
    assert_select "#nav a[aria-current=page]", text: "Sessions"
  end
end
