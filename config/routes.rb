Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      scope :auth do
        post 'login', to: 'auth#login'
        post 'activate', to: 'auth#activate'
        post 'verify', to: 'auth#verify'
      end

      scope :users do
      end

      scope :product do
      end
    end
    resources :products do
      collection do
        post :create_photo
      end
    end
  end
end
