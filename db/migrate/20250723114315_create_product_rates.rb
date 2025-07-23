class CreateProductRates < ActiveRecord::Migration[8.0]
  def change
    create_table :product_rates do |t|
      t.timestamps
    end
  end
end
