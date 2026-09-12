class ProgressController < ApplicationController
  def index
    @progress = ClubProgress.build(current_user.trackman_sessions)
  end
end
