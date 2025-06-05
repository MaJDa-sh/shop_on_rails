class Api::ProductsController < ApplicationController
  def index
    @products = Product.all
  end

  def show
    @product = Product.find(params[:id])
  end

  def create
    @product = Product.new(product_params)
  
    if @product.save
      if params[:photos]
        @product.photos.attach(params[:photos])
      end
      render json: @product, status: :created
    else
      render json: @product.errors, status: :unprocessable_entity
    end
  end

  def update
    @product = Product.find(params[:id])
    @product.update!(product_params)
  end

  def destroy
    @product = Product.delete(params[:id])
  end

  private

  def product_params
    params.require(:product).permit(:id, :name, :price, :description, photos: [])
  end
end
