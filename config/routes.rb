Pwb::Engine.routes.draw do
  root to: 'welcome#index'
  resources :welcome, only: :index
end
