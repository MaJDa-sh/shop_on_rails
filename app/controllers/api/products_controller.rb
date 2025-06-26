class Api::ProductsController < ApplicationController
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
    Rails.logger.debug "Product ID: #{params[:id]}"
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

  def set_url_options
    ActiveStorage::Current.url_options = {
      host: request.base_url
    }
  end

  def product_params
    params.require(:product).permit(
      :id, :name, :price, :description,
      product_photos_attributes: [:id, :_destroy],
      product_photo_ids: []
    )
  end
  def create_photo_params
    params.require(:product_photo).permit(
      :id, :image, :product_id
    )
  end
end
