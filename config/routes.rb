Rails.application.routes.draw do
  devise_for :users
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root "sessions#index"
  resource :sessions, except: [:edit]
  post "sessions/callback"
  post "sessions/send_mail"
  
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

end
