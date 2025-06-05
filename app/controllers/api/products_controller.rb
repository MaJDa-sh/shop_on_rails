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
    @product = Product.update!(product_params)
  end

  def delete
    @product = Product.delete(params[:id])
  end

  private

  def product_params
    params.require(:product).permit(:id, :name, :price, :description)
  end
end
