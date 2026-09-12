# A one-click "view the demo" link: GET /demo logs the visitor in as the
# fixed demo account (see DemoData) and drops them on the dashboard. Always
# that one account, never parameterized — this must never become a way to
# log in as an arbitrary user.
class DemoController < ApplicationController
  skip_before_action :require_login

  def enter
    user = User.find_by(email: DemoData::EMAIL)

    if user
      login(user)
      redirect_to root_path, notice: "You're in the Rough estimates demo account — the data is synthetic. Look around freely."
    else
      redirect_to login_path, alert: "The demo account isn't set up yet."
    end
  end
end
