module Api
  module V1
    class PagesController < BaseController
      def show
        render json: { markdown: page.markdown, updated_at: page.updated_at }
      end

      def update
        page.update!(markdown: params.require(:markdown))
        render json: { markdown: page.markdown, updated_at: page.updated_at }
      end

      private

      def page
        @page ||= Page.current
      end
    end
  end
end
