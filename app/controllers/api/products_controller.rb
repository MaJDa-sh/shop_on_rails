class Api::ProductsController < ApplicationController
  include Rails.application.routes.url_helpers
  def index
    @products = Product.all
  end

  def show
    @product = Product.find(params[:id])
  end

  def create
    @product = Product.create!(product_params)
  end

  def update
    Rails.logger.info "Incoming photo IDs: #{params[:product][:product_photo_ids]}"
    @product = Product.find(params[:id])
    @product.update!(product_params)
  end

  def destroy
    @product = Product.find(params[:id])
    @product.destroy
  end

  def create_photo
    @photo = ProductPhoto.create!(create_photo_params)
    render json: {id: @photo.id, url: url_for(@photo.image)}
  end

  private

  def product_params
    params.require(:product).permit(
      :id, :name, :price, :description,
      product_photos_attributes: %i[id _destroy],
      product_photo_ids: []
    )
  end

  def create_photo_params
    params.require(:product_photo).permit(
      :id, :image, :product_id
    )
  end
end
