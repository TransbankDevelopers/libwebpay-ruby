Rails.application.routes.draw do
 
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  root to: 'pages#index'

  match "/pages/tbknormal" => "pages#tbknormal", via: [:get, :post]
  match "/pages/tbkcapture" => "pages#tbkcapture", via: [:get, :post]
  match "/pages/tbknormalcapture" => "pages#tbknormalcapture", via: [:get, :post]
  match "/pages/tbkoneclick" => "pages#tbkoneclick", via: [:get, :post]
  match "/pages/tbkcomplete" => "pages#tbkcomplete", via: [:get, :post]
  match "/pages/tbkmallnormal" => "pages#tbkmallnormal", via: [:get, :post]
  match "/pages/tbknullifynormal" => "pages#tbknullifynormal", via: [:get, :post]
  match "/pages/tbknullifymallnormal" => "pages#tbknullifymallnormal", via: [:get, :post]
  match "/pages/tbknullifycomplete" => "pages#tbknullifycomplete", via: [:get, :post]


  #get "/pages/tbkoneclick", :controller => "pages", :action => "tbkoneclick"
  #via: [:get, :post]

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
