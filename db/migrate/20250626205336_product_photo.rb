class ProductPhoto < ActiveRecord::Migration[8.0]
  def change
    create_table :product_photos, id: :uuid do |t|
      t.references :product, null: true, foreign_key: true, type: :uuid
      t.timestamps
    end
  end
end
