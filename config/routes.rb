Rails.application.routes.draw do
  namespace :api do
    resources :products do
      collection do
        post :create_photo
      end
    end
  end
end
