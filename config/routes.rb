require 'sidekiq/web'

Rails.application.routes.draw do
  resources :trades

  resources :conversations do
    resources :messages
  end

  devise_for :users
  root to: 'trades#index'
end
