require 'rails_helper'

RSpec.describe "Homes", type: :request do
  describe "GET /intro" do
    it "returns http success" do
      get "/home/intro"
      expect(response).to have_http_status(:success)
    end
  end

end
