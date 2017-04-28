Rails.application.routes.draw do
  get 'lti/xml'

  get 'lti/cred'

  devise_for :users
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  root 'main#index', via: :all
  post '/' => 'main#index'
  match 'lti/register' => 'lti#register', via: [:post, :get]

  post 'lti/add_content' => 'lti#add_content'
  get 'item/:id' => 'main#item'
  get 'endpoint' => 'main#endpoint'

  get 'lti/oauth' => 'lti#oauth'
  post 'main/send_choosen_objects'
end
