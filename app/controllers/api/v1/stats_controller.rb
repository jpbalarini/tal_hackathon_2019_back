class Api::V1::StatsController < ApplicationController
  def index
    service_params = stats_params.to_hash.symbolize_keys
    service_params[:top_left] = JSON.parse(service_params[:top_left])
    service_params[:bottom_right] = JSON.parse(service_params[:bottom_right])
    elements = StatsService.get(service_params)
    render json: { transactions: elements['hits'] }, status: 200
  end

  def stats_params
    params.permit(:year, :make, :model, :max_turn_over, :days_ago,
      :precision, :bottom_right, :top_left, :routing, :size)
  end
end
