module Api
  class CollectorsController < BaseController
    def coverage
      render json: { collectors: [], runtime: "rails" }
    end
  end
end
