require "test_helper"

class ApiFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "golfer@example.com", password: "password123")
    @headers = { "Authorization" => "Bearer #{@user.api_key}" }
  end

  # No mocking library needed (Minitest 6 dropped Object#stub/Minitest::Mock):
  # swap TrackmanReport::Client.new for the block's duration, plain Ruby.
  def with_fake_trackman
    TrackmanReport::Client.define_singleton_method(:new) { FakeTrackmanClient.new }
    yield
  ensure
    TrackmanReport::Client.singleton_class.send(:remove_method, :new)
  end

  test "rejects requests without a valid api key" do
    get api_v1_sessions_path
    assert_response :unauthorized

    get api_v1_sessions_path, headers: { "Authorization" => "Bearer nope" }
    assert_response :unauthorized
  end

  test "adding a session via the API is agent-friendly: idempotent, JSON in, JSON out" do
    with_fake_trackman do
      post api_v1_sessions_path, params: { url: "https://example.com?r=agent-1" }, headers: @headers
      assert_response :created
      body = JSON.parse(response.body)
      assert_equal "agent-1", body["report_id"]
      assert_equal 3, body["shot_count"]

      post api_v1_sessions_path, params: { url: "https://example.com?r=agent-1" }, headers: @headers
      assert_response :ok
    end
  end

  test "summary and progress endpoints reflect ingested sessions" do
    with_fake_trackman do
      TrackmanIngestor.call(user: @user, url: "https://example.com?r=agent-2", client: FakeTrackmanClient.new)
    end

    get api_v1_summary_path, headers: @headers
    assert_response :success
    summary = JSON.parse(response.body)
    assert_equal 1, summary.size
    assert_equal 2, summary.first["clubs"].size

    get api_v1_progress_path, headers: @headers
    assert_response :success
    progress = JSON.parse(response.body)
    assert_includes progress.keys, "7Iron"
  end

  test "session show returns raw shots and supports csv" do
    result = TrackmanIngestor.call(user: @user, url: "https://example.com?r=agent-3", client: FakeTrackmanClient.new)

    get api_v1_session_path(result.session), headers: @headers
    assert_response :success
    assert_equal 3, JSON.parse(response.body)["shots"].size

    get api_v1_session_path(result.session, format: :csv), headers: @headers
    assert_response :success
    assert_match "club,shot_number", response.body
  end

  test "index of endpoints is discoverable" do
    get api_v1_path, headers: @headers
    assert_response :success
    assert JSON.parse(response.body)["endpoints"].present?
  end
end
