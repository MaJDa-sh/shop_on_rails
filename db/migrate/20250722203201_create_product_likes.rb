class CreateProductLikes < ActiveRecord::Migration[8.0]
  def change
    create_table :product_likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product, type: :uuid, null: false, foreign_key: true
      t.timestamps
      t.index %i[user_id product_id], unique: true
    end
  end
end
