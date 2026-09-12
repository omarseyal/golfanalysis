require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(**opts)
    User.new({ email: "golfer@example.com", password: "password123" }.merge(opts))
  end

  test "valid user can authenticate with the right password" do
    user = build_user.tap(&:save!)
    assert user.authenticate("password123")
    refute user.authenticate("wrong")
  end

  test "generates a unique api_key on create" do
    user = build_user.tap(&:save!)
    assert user.api_key.present?
  end

  test "regenerate_api_key changes the key" do
    user = build_user.tap(&:save!)
    old_key = user.api_key
    user.regenerate_api_key
    refute_equal old_key, user.api_key
  end

  test "normalizes email to lowercase and strips whitespace" do
    user = build_user(email: "  Golfer@Example.com  ").tap(&:save!)
    assert_equal "golfer@example.com", user.email
  end

  test "requires a unique email" do
    build_user.save!
    dup = build_user
    refute dup.valid?
    assert_includes dup.errors[:email], "has already been taken"
  end

  test "rejects an invalid email format" do
    user = build_user(email: "not-an-email")
    refute user.valid?
  end

  test "requires a password of at least 8 characters" do
    user = build_user(password: "short")
    refute user.valid?
  end
end
