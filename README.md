# Create a trading app with in-app messaging
Welcome to my latest _Let's Build: With Ruby on Rails_ series. This build will dive a little deeper into relationships within a Ruby on Rails application and teach you have to create a simple messaging app within your main rails app.

Think of the messaging strucuture like an ongoing converstation. Users can initially create a conversation and always look back to their history. This app is a _start_ to what could be a fully featured messaging area within your own app but I want to introduce new methods include scopes, params, and more that come bundled with Rails.

## Kicking things off, literally
I created my own Rails application template called [Kick Off](https://github.com/justalever/kickoff) of which you are free to use. Follow the steps in the videos to kick off your own projects. You'll need to clone the repo to your own machine and of course be setup to run Ruby on Rails.

At the time of this recording I am using `Rails 5.2` and `Ruby 2.5.1`.


### Scaffold the trade
```bash
$ rails g scaffold Trade title:string description:text user:references
```

### Adjust User model to include many trades

```ruby
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  has_many :trades
end
```

### Add ActiveStorage support
```bash
$ rails active_storage:install
```

```
$ rails db:migrate
```

### Update model to include many images

```ruby
class Trade < ApplicationRecord
  belongs_to :user
  has_many_attached :images, dependent: :destroy
end
```

### Update trades controller

```ruby
  def trade_params
    params.require(:trade).permit(:title, :description, :user_id, images: [])
  end
```

### Add in user related criteria on create and new actions
Here we add the referenced `current_user` to the mix when a trade is created. This allows us to add an `user_id` to the `trade` itself so each user is related to their own trades. We also set a before action to make sure anyone who creates a new trade is logged in so we can actually associate the user with the trade.

```ruby
class TradesController < ApplicationController
  before_action :set_trade, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :show]

  # GET /trades
  # GET /trades.json
  def index
    @trades = Trade.all
  end

  # GET /trades/1
  # GET /trades/1.json
  def show
  end

  # GET /trades/new
  def new
    @trade = current_user.trades.build
  end

  # GET /trades/1/edit
  def edit
  end

  # POST /trades
  # POST /trades.json
  def create
    @trade = current_user.trades.build(trade_params)

    respond_to do |format|
      if @trade.save
        format.html { redirect_to @trade, notice: 'Trade was successfully created.' }
        format.json { render :show, status: :created, location: @trade }
      else
        format.html { render :new }
        format.json { render json: @trade.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /trades/1
  # PATCH/PUT /trades/1.json
  def update
    respond_to do |format|
      if @trade.update(trade_params)
        format.html { redirect_to @trade, notice: 'Trade was successfully updated.' }
        format.json { render :show, status: :ok, location: @trade }
      else
        format.html { render :edit }
        format.json { render json: @trade.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /trades/1
  # DELETE /trades/1.json
  def destroy
    @trade.destroy
    respond_to do |format|
      format.html { redirect_to trades_url, notice: 'Trade was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_trade
      @trade = Trade.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def trade_params
      params.require(:trade).permit(:title, :description, :user_id, images: [])
    end
end
```


### Generate migration for conversations
```bash
$ rails g migration createConversations
```

Create the table as follows:

```ruby
class CreateConversations < ActiveRecord::Migration
 def change
  create_table :conversations do |t|
   t.integer :sender_id
   t.integer :recipient_id

   t.timestamps
  end
 end
end
```

### Generate migration for messages

```bash
$ rails g migration createMessages
```

Create the table as follows:

```ruby
class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
    t.text :body
    t.references :conversation, index: true
    t.references :user, index: true

    t.timestamps
    end
  end
end
```

### Generate Conversation Model

```bash
$ rails g model Conversation --skip-migration
```

### Update the Conversation model

```ruby
# app/models/conversation.rb

class Conversation < ApplicationRecord
  belongs_to :sender, foreign_key: :sender_id, class_name: "User"
  belongs_to :recipient, foreign_key: :recipient_id, class_name: "User"

  has_many :messages

  validates_uniqueness_of :sender_id, scope: :recipient_id

  # This scope validation takes the sender_id and recipient_id for the conversation and checks whether a conversation exists between the two ids because we only want two users to have one conversation.

  scope :between, -> (sender_id, recipient_id) do
    where("(conversations.sender_id = ? AND conversations.recipient_id = ?) OR (conversations.sender_id = ? AND conversations.recipient_id = ?)", sender_id, recipient_id, recipient_id, sender_id)
  end
end
```

### Message model

```bash
$ rails g model Message --skip-migration
```

```ruby
# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :user
  validates_presence_of :body, :conversation_id, :user_id

  def message_time
    created_at.strftime("%m/%d/%y at %l:%M %p")
  end
end
```

### Conversations Controller

```ruby
# app/controllers/conversations_controller.rb
class ConversationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @users = User.all
    @conversations = Conversation.all
  end

  def create
    if Conversation.between(params[:sender_id], params[:recipient_id]).present?
      @conversation = Conversation.between(params[:sender_id], params[:recipient_id]).first
    else
      @conversation = Conversation.create!(conversation_params)
    end
    redirect_to conversation_messages_path(@conversation)
  end

  private
    def conversation_params
      params.permit(:sender_id, :recipient_id)
    end

end
```

### Message Controller
Let's just create a controller by hand

```ruby
# app/controllers/messages_controller.rb
class MessagesController < ApplicationController
  before_action :find_conversation

  def index
    @messages = @conversation.messages

    if @messages.length > 10
      @over_ten = true
      @messages = @messages[-10..-1]
    end

    if params[:m]
      @over_ten = false
      @messages = @conversation.messages
    end

    @message = @conversation.messages.new
  end

  def create
    @message = @conversation.messages.new(message_params)
    if @message.save
      redirect_to conversation_messages_path(@conversation)
    end
  end

  def new
    @message = @conversation.messages.new
  end



  private

    def message_params
      params.require(:message).permit(:body, :user_id)
    end

    def find_conversation
      @conversation = Conversation.find(params[:conversation_id])
    end
end
```

### Update the routes

```ruby
require 'sidekiq/web'

Rails.application.routes.draw do
  resources :trades

  resources :conversations do
    resources :messages
  end

  devise_for :users
  root to: 'trades#index'
end

```

### Sprinkle in some useful helpers
```ruby
# app/helpers/application_helper.rb
module ApplicationHelper

   def gravatar_for(user, options = { size: 200})
    gravatar_id = Digest::MD5::hexdigest(user.email.downcase)
    size = options[:size]
    gravatar_url = "https://secure.gravatar.com/avatar/#{gravatar_id}?s=#{size}"
    image_tag(gravatar_url, alt: user.name, class: "border-radius-50")
  end

  def markdown_to_html(text)
    Kramdown::Document.new(text, input: "GFM").to_html
  end

  def trade_author(trade)
    user_signed_in? && current_user.id == trade.user_id
  end

end
```

### Trade Index View

```html
<!-- app/views/trades/index.html.erb -->
<h1 class="title is-1">Trades</h1>
<p class="subtitle is-5">Looking to get rid of gear but not lose money. Trade some of your gear!</p>
<div class="columns">
<% @trades.each do |trade| %>
  <div class="column is-3">
    <%= render trade, trade: trade %>
  </div>
<% end %>
</div>
```


### Trade index view trade partial

```html
<!-- app/views/trades/_trade.html.erb -->
<div class="card">
  <div class="card-image">
    <figure class="image is-square">
      <%= link_to image_tag(trade.images.first.variant(resize: "640x480>")), trade %>
    </figure>
  </div>
  <div class="card-content">
    <h3 class="pt1 title is-5"><%= trade.title %></h3>
    <p class="pv1"><%= truncate(trade.description, length: 120) %></p>
    <div class="media pt3">
      <div class="media-left pt3">
        <figure class="image is-48x48">
          <%= gravatar_for(trade.user, size: 96) %>
        </figure>
      </div>
      <div class="media-content">
        <p class="has-text-weight-bold mb0"><%= trade.user.name %></p>
        <p class="is-italic mb0"><time>posted <%= time_ago_in_words(trade.created_at) %> ago</time></p>
      </div>
    </div>
  </div>
</div>
```

### Trade Show View
```html
<!-- app/views/trades/show.html.erb -->
<div class="columns">
  <div class="column is-8">
    <h1 class="title is-1"><%= @trade.title %></h1>
    <div class="content">
      <p class="pb3 border-bottom">Post <%= time_ago_in_words(@trade.created_at) %> ago</p>
      <div class="pt1"><%= sanitize markdown_to_html(@trade.description) %></div>
    </div>

    <% if @trade.images.attached? %>
      <div class="columns is-multiline">
        <% @trade.images.each do |image| %>
          <div class="column is-one-third">
            <%= image_tag image.variant(resize: "800x600>") %>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>

  <div class="column is-3 is-offset-1">
    <% if trade_author(@trade) %>
      <div class="bg-light pa3 mb4 border-radius-3">
        <p class="f6 pb1">Author actions:</p>
        <div class="button-group">
          <%= link_to "Edit trade: #{@trade.title}", edit_trade_path(@trade), class: 'button is-small' %>
          <%= link_to "Back", trades_path, class: "button is-small" %>
        </div>
      </div>
    <% end %>
    <div class="pr5 mb4">
      <p class="text-align-left f6">Trade author:</p>
      <div class="inline-block nudge-down-10"><%= gravatar_for @trade.user, size: 32 %></div>
      <div class="inline-block"><%= @trade.user.name %></div>
    </div>
    <% if user_signed_in? && current_user.id != @trade.user_id %>
      <%= link_to "Message #{@trade.user.name}", conversations_path(sender_id: current_user.id, recipient_id: @trade.user.id), method: 'post', class:"button is-link" %>
    <% elsif user_signed_in? && current_user.id == @trade.user_id  %>
      <%= link_to "Conversations", conversations_path %>
    <% else %>

    <%= link_to "Sign up to message #{@trade.user.name}", new_user_registration_path %>
    <% end %>
  </div>
</div>
```


### Messages index view
```html
<!-- app/views/messages/index.html.erb -->
<h1 class="title is-4">Message <%= @conversation.recipient.name %></h1>

<% if @over_ten %>
  <%= link_to "Show previous", '?m=all', class:'button is-link' %>
<% end %>

<section id="messages" class="mb4">
  <% @messages.each do |message| %>
    <% if message.body %>
      <% user = User.find(message.user_id) %>
      <article class="message is-dark">
        <div class="message-body">
          <div class="inline-block nudge-down-10 pr2"><%= gravatar_for user, size: 32 %></div>
          <div class="inline-block"><strong><%= user.name %></strong> <%= message.message_time %></div>
          <div class="block pt4">
            <div class="f4"><%= sanitize markdown_to_html(message.body) %></div>
          </div>
        </div>
      </article>
    <% end %>
  <% end %>
</section>

<%= form_for [@conversation, @message] do |f| %>
  <%= f.text_area :body, class: "textarea", placeholder: "Inquire about a trade..." %>
  <%= f.text_field :user_id, value: current_user.id, type: "hidden"  %>
  <div class="text-align-right">
    <%= f.submit "Send message", class: "button is-link is-large mt3" %>
  </div>
<% end %>
```

### Conversations index view

```html
<div class="columns">
  <div class="column is-3">
    <h3 class="title is-3">All Users</h3>
    <% @users.each do |user| %>
      <% if user.id != current_user.id %>
       <%= link_to "Message #{user.name}", conversations_path(sender_id: current_user.id, recipient_id: user.id), method: "post" %>
      <% end %>
    <% end %>
  </div>

  <div class="column is-7">
    <h3 class="title is-3">Conversations</h3>
    <% @conversations.each do |conversation| %>
      <% if conversation.sender_id == current_user.id || conversation.recipient_id == current_user.id %>
        <% if conversation.sender_id == current_user.id %>
          <% recipient = User.find(conversation.recipient_id) %>
        <% else %>
          <% recipient = User.find(conversation.sender_id) %>
        <% end %>
        <% unless current_user.id == recipient %>
          <div class="columns">
            <div class="column">
              <div class="inline-block nudge-down-10"><%= gravatar_for recipient, size: 32 %></div>
              <div class="inline-block"><%= link_to recipient.name, conversation_messages_path(conversation) %></div>
            </div>
          </div>
        <% end %>
      <% end %>
    <% end %>
  </div>
</div>
```


