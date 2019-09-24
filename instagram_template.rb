def add_gems
	gem 'omniauth', '~> 1.9'
  gem 'omniauth-facebook', '~> 5.0'
	gem 'koala', '~> 2.4'
	gem 'haml', '~> 5.0', '>= 5.0.4'
	gem 'pry-rails', '~> 0.3.4'
	gem 'figaro', '~> 1.1', '>= 1.1.1'
	gem 'jquery-rails', '~> 4.3', '>= 4.3.3'
	gem 'bootstrap', '~> 4.2', '>= 4.2.1'
	gem 'sassc-rails', '~> 2.1'

	gem_group :development do
		gem 'better_errors', '~> 2.5'
		gem 'binding_of_caller', '~> 0.8.0'
	end

	gem_group :development, :test do
		gem 'rspec-rails', '~> 3.8.1'
		gem 'factory_bot_rails', '~> 4.11', '>= 4.11.1'
	end
end

def add_figaro
	run 'bundle exec figaro install'
	env_code = <<-CODE
FACEBOOK_KEY: 'NEED'
FACEBOOK_SECRET: 'NEED'
	CODE
	file 'config/application.yml', env_code, force: true
end

def add_omniauth_config
	initializer 'omniauth.rb', <<-CODE
Rails.application.config.middleware.use OmniAuth::Builder do
	provider :facebook, 
					ENV['FACEBOOK_KEY'], 
					ENV['FACEBOOK_SECRET'], 
					scope: 'instagram_basic, manage_pages, instagram_manage_insights',
					name: 'instagram_business'
end
	CODE
end

def add_bootstrap
	run 'rm -rf app/assets/stylesheets/application.css'

	application_css = <<-CODE
@import "bootstrap";
@import "base/*";
@import "components/*";
@import "pages/*";

html,
body {
  font-size: 16px;
  background-color: #f3efec;
}

	CODE
	create_file 'app/assets/stylesheets/application.css.scss', application_css
end

def set_up_css_structure
	run 'mkdir app/assets/stylesheets/base'
	run 'mkdir app/assets/stylesheets/components'
	run 'mkdir app/assets/stylesheets/pages'
	run 'touch app/assets/stylesheets/pages/home.scss'

	breakpoints_css = <<-CODE
// Breakpoints
$break-xs: 576px;
$break-sm: 768px;
$break-md: 992px;
$break-lg: 1200px;

// Styleguide: Breakpoints.1
@mixin respond-to($media) {
	@if $media == xs {
		@media only screen and (max-width: $break-xs) { @content; }
	}

	@else if $media == sm {
		@media only screen and (max-width: $break-sm) { @content; }
	}

	@else if $media == md {
		@media only screen and (max-width: $break-md) { @content; }
	}

	@else if $media == lg {
		@media only screen and (max-width: $break-lg) { @content; }
	}
}
	CODE
	create_file 'app/assets/stylesheets/base/breakpoints.scss', breakpoints_css

	alert_css = <<-CODE
.alert {
	position: absolute;
	top: 10px;
	width: 80vw;
	left: 10vw;
}
	CODE
	create_file 'app/assets/stylesheets/components/alert.scss', alert_css
end

def create_user
	rows = %w{
		instagram_id
		facebook_id
		page_id
		facebook_access_token
		instagram_access_token
		instagram_handle
	}
		
	generate(:model, "User", *rows)

	model_code = <<-CODE

def self.create_from_omniauth(auth)
	user = where(facebook_id: auth['uid']).first_or_initialize
	user.facebook_access_token = auth['credentials']['token']
	user.save
	user
end

def facebook_client
	InstagramClient.new(self.facebook_access_token)
end
def instagram_client
	InstagramClient.new(self.instagram_access_token, self.instagram_id)
end

def instagram_pages
	facebook_client.user_pages_with_instagram
end
	CODE

	inject_into_class "app/models/user.rb", "User", model_code, after: "class User < ApplicationRecord"

end

def create_seed_data
	seed_code = <<-CODE
User.destroy_all

user = User.create(
	instagram_access_token: "4756774.d146b6e.8f1ecbb5d62340dea84b6b53b9a93286",
	instagram_id: "4756774",
	instagram_handle: "parkerbarkers",
)
	CODE
	create_file 'db/seeds.rb', seed_code, force: true
end

def set_up_rspec
	run `rails generate rspec:install`
end

def create_session_controller
	session_code = <<-CODE
class SessionsController < ApplicationController
  def new
    redirect_to 'auth/instagram_business', status: 301
  end

  def create
    user = User.create_from_omniauth(auth_hash)
    session[:user_id] = user.id.to_s
    if user.new_record?
      redirect_to edit_instagram_path, success: 'Signed In'
    else
      redirect_to root_path, success: "Signed In"
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "Logged out."
  end

  protected

  def auth_hash
    request.env['omniauth.auth']
  end
end

	CODE

	create_file 'app/controllers/sessions_controller.rb', session_code

	# add route back to authentication
	route "get '/auth/:provider/callback', to: 'sessions#create'"
	route "get '/logout', to: 'sessions#destroy'"
end

def generate_application_controller
	controller_code = <<-CODE
class ApplicationController < ActionController::Base
	def current_user
		return User.first if Rails.env.development?
		return unless session[:user_id].present?
		@current_user ||= User.find(session[:user_id])
	end
	helper_method :current_user

	def authenticate_user!
		redirect_to root_path, notice: "Please pledge first." if current_user.nil?
	end
end
	CODE
	
	create_file 'app/controllers/application_controller.rb', controller_code, force: true
end

def add_home_page
	controller_code = <<-CODE
class StaticController < ApplicationController
	def home; end
end
	CODE
	create_file 'app/controllers/static_controller.rb', controller_code
	run 'mkdir app/views/static/'
	create_file 'app/views/static/home.haml', "%h1 Welcome to this Template"
	route "root to: 'static#home'"
end

def generate_application_helper
	helper_code = <<-CODE
module ApplicationHelper
  def bootstrap_class_for flash_type
    { success: "alert-success", error: "alert-error", alert: "alert-warning", notice: "alert-info" }[flash_type.to_sym] || flash_type.to_s
  end
end
	CODE
	
	create_file 'app/helpers/application_helper.rb', helper_code, force: true
end

def set_up_flash_notification
	flash_code = <<-CODE
- flash.each do |msg_type, message|
	%div{:class => "alert \#{bootstrap_class_for(msg_type)}"}
		.container
			%button.close{"data-dismiss" => "alert"}
				%span ×
			= message
	CODE
	create_file 'app/views/layouts/partials/_flash.haml', flash_code
end

def set_nav
	nav_code = <<-CODE
%nav.navbar.navbar-expand-lg.navbar-light.bg-light
  %a.navbar-brand{href: "/"} Brand Name
  %button.navbar-toggler{"aria-control": "navBarToggle", "aria-expande": "false", "aria-labe": "Toggle navigation", "data-targe": "#navBarToggle", "data-toggl": "collapse", type: "button"}
    %span.navbar-toggler-icon
  #navBarToggle.collapse.navbar-collapse
    %ul.navbar-nav.mr-auto.mt-2.mt-lg-0
      %li.nav-item.active
        %a.nav-link{href: "/"}
          Home
          %span.sr-only (current)
    %form.form-inline.my-2.my-lg-0
      - if current_user
        %a{href: "/logout", class: "btn btn-outline-success"} Logout
      - else
        %a{href: "/auth/instagram_business", class: "btn btn-outline-success"} Login

	CODE
	create_file 'app/views/layouts/partials/_nav.haml', nav_code
end

def set_footer
		footer_code = <<-CODE
%footer.c-footer
	.container
		.col-12
			Footer Copy Will Go Here
			Dont Forget to a https://termsfeed.com/
	CODE
	create_file 'app/views/layouts/partials/_footer.haml', footer_code
end

def set_up_layout
	layout = <<-CODE
!!!
%html
	%head
		- title = "Best Title"
		- description = ""
		- og_image = 'https://s3.amazonaws.com/assets.fohrcard.com/uploads/CX6LlYE/FohrMetaImg.jpg'
		- fb_id = ""
		- site_name = ""
		- site_url = ""

		-# Site Meta
		%title= content_for?(:title) ? content_for(:title) : title
		%meta{content: "text/html; charset=UTF-8", "http-equiv": "Content-Type"}
		%meta{content: description, name: "description"}
		%meta{content: "", name: "keywords"}
		%meta{content: "index, nofollow", name: "robots"}
		%meta{content: "5 days", name: "revisit-after"}
		%meta{content: "width=device-width, initial-scale=1", name: "viewport"}
		
		-# Favicons 
		%link{href: "/favicon.ico", rel: "shortcut icon", type: "image/x-icon"}
		%link{href: "/favicon.ico", rel: "icon", type: "image/x-icon"}

		-# OG TAGS
		%meta{ name: "description", content: description}
		%meta{ name: "twitter:card", content: "summary" }
		%meta{ name: "twitter:title", content: title }
		%meta{ name: "twitter:image", content: content_for?(:meta_img) ? yield(:meta_img) : og_image }
		%meta{ property: "og:title", content: title }
		%meta{ property: "og:type", content: "website" }
		%meta{ property: "og:url", content: content_for?(:meta_url) ? yield(:meta_url) : site_url }
		%meta{ property: "og:image", content: content_for?(:meta_img) ? yield(:meta_img) : og_image }
		%meta{ property: "og:image:width", content: content_for?(:meta_img_width) ? yield(:meta_img_width) : ''}
		%meta{ property: "og:image:height", content: content_for?(:meta_img_height) ? yield(:meta_img_height) : ''}
		%meta{ property: "og:description", content: description }
		%meta{ property: "og:site_name", content: site_name }
		%meta{ itemscope: "", itemtype: "http://schema.org/Article" }
		%meta{ itemprop: "title", content: title }
		%meta{ itemprop: "name", content: title }
		%meta{ itemprop: "description", content: description }
		%meta{ itemprop: "image", content: content_for?(:meta_img) ? yield(:meta_img) : og_image }
		%meta{ property: "fb:app_id", content: fb_id }

		= csrf_meta_tags
		= csp_meta_tag
		= stylesheet_link_tag    'application', media: 'all', 'data-turbolinks-track': 'reload'
		= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload'
	%body
		= render "layouts/partials/flash"
		= render "layouts/partials/nav"
		= yield
		= render "layouts/partials/footer"

	CODE
	run 'rm -rf app/views/layouts/application.html.erb'
	create_file 'app/views/layouts/application.haml', layout
end

def create_instagram_client
	client_code = <<-CODE
# frozen_string_literal: true

# Handle all api calls for instagram business
class InstagramClient
  def initialize(access_token, id = 'me')
    @client = ::Koala::Facebook::API.new(access_token)
    @id = id
  end

  def user_pages
    @client.get_connections("me", "accounts")
  end


  # get user pages that have instagram handles connected 
  def user_pages_with_instagram
    pages = user_pages
    insta_pages = pages.map do |page|
      id = page["id"]
      instagram_id = self.instagram_business_account_id(id)
      next if instagram_id.nil?
      instagram_details = self.instagram_user_details(instagram_id)
      page["instagram_handle"] = instagram_details["username"]
      page["instagram_id"] = instagram_id
      page
    end

    insta_pages.compact
  end

  def instagram_business_account_id(id = 'me')
    # me is a facebook_page_id
    response = @client.get_object(id, fields: 'instagram_business_account')
    response['instagram_business_account']['id'] 
  rescue
    nil
  end

  ##
  ## INSTAGRAM DATA
  ##
  def instagram_user_details(id = @id)
    # https://developers.facebook.com/docs/instagram-api/reference/user
    fields = 'biography,id,ig_id,followers_count,follows_count,media_count,name,profile_picture_url,username,website'
    @client.get_object(id, fields: fields)
  end

  # We'll need to also tie into the instagram api to get fuller tagged data
  def instagram_user_recent_media(limit = 33)
    fields = 'media_type,permalink,thumbnail_url,media_url,like_count,comments_count,ig_id,caption,timestamp'
    @client.get_connection(@id, 'media', fields: fields, limit: limit)
  end

  # {"media_type"=>"IMAGE",
  # "permalink"=>"https://www.instagram.com/p/Bf81lBsAmBv/",
  # "media_url"=>
  #  "https://scontent.xx.fbcdn.net/v/t51.12442-9/28751617_188851321715624_7065626002587648000_n.jpg?oh=f005d1b89317c4648d199dfb828dcf8f&oe=5B0713A0",
  # "like_count"=>0,
  # "comments_count"=>0,
  # "ig_id"=>"1728491997901250671",
  # "caption"=>"Thanks @flyingeyebooks",
  # "timestamp"=>"2018-03-05T17:51:55+0000",
  # "id"=>"17929475242053619"}
  # def instagram_stories
  #   stories = @client.get_connection(@id, 'stories', fields: 'media_type,permalink,thumbnail_url,media_url,ig_id,caption,timestamp')
    
  #   stories.each do |s| 
  #     caption = s["caption"]
  #     s["media_type"] = "STORY-\#{s["media_type"]}"
  #     s["tagged_users"] = caption.to_s.scan(/@\w+/).map{|t| t.gsub("@", "")}.uniq.join(" ")
  #     s["tags"] = caption.to_s.scan(/#\w+/).map{|t| t.gsub("@", "")}.uniq.join(" ")
  #     s["created_time"] = Time.parse(s["timestamp"]).to_i
  #     s["caption"] = caption
  #   end
  # end

  # The id is a media ID
  def media_insights(id, type = nil)
    metric_options = media_insights_parameters(type)
    response = @client.get_connection(id, 'insights', {metric: metric_options})
    response.map{|v| [v["name"], v["values"][0]["value"]]}.to_h
  end

  def batch_media_insights(posts)
    # Use facebook batch protocol for faster data pulls
    @client.batch do |batch_api|
      # cycle through each post to build a insights call
      posts.each_with_index do |post, index|
        next if post.nil?
        metric_options = media_insights_parameters(post["media_type"])
        # responses should be added to the post directly under fb_stats
        id = post['fb_id'] || post['id']
        batch_api.get_connection(id, 'insights', {metric: metric_options}) do |response| 
          response_data = response.map{|v| [v['name'], v['values'][0]['value']]}.to_h
          posts[index].merge!(response_data) if response_data.present?
        rescue => e
          posts[index]['insights_error'] = e.message.to_s
        end
      end
    end

    posts
  end

  # The id is a media ID
  def children_media(id)
    @client.get_connection(id, 'children', fields: 'media_type,thumbnail_url,media_url')
  end

  def instagram_user_account_insights
    since = 30.days.ago.to_i
    now = Time.now.to_i
    day_week_days_28 = {period: 'day', metric: 'impressions,reach', since: since, until: now} # %w(day week days_28)
    @client.get_connection(@id, 'insights', day_week_days_28)
  end

  def instagram_user_extra_account_insights
    since = 30.days.ago.to_i
    now = Time.now.to_i
    daily = {period: 'day', metric: 'follower_count,email_contacts,phone_call_clicks,text_message_clicks,get_directions_clicks,website_clicks,profile_views', since: since, until: now}

    @client.get_connection(@id, 'insights', daily)
  end

  def instagram_user_demographics
    lifetime = {period: 'lifetime', metric: 'audience_gender_age,audience_locale,audience_country,audience_city,online_followers'}
    @client.get_connection(@id, 'insights', lifetime)
  end

  #
  # Mentions
  #

  def instagram_tagged_in_media
    @client.get_connection(@id, 'tags')
  end
  
  # We listen to the mentions endpoint to get the ids of comment and caption mentions
  # We then get those mentions by looking at the specific id

  #
  # Comments
  #
  def instagram_media_comments(media_id)
    # returns 50 comments
    comment_ids = @client.get_connection(media_id, "comments")
    # cycle through those comments
  end

  private

  def media_insights_parameters(media_type)
    metric_options = ''

    case media_type.upcase
    when "IMAGE"
      metric_options = 'engagement,impressions,reach,saved'
    when "CAROUSEL_ALBUM", "CAROUSEL" # need to verify this media type
      metric_options = 'engagement,impressions,reach,saved,carousel_album_engagement,carousel_album_impressions,carousel_album_reach,carousel_album_saved,carousel_album_video_views'
    when "VIDEO"
      metric_options = 'engagement,impressions,reach,saved,video_views'
    when "STORY-IMAGE", "STORY-VIDEO"
      metric_options = 'exits,impressions,reach,replies,taps_forward,taps_back'
    else
      metric_options = 'engagement,impressions,reach,saved'
    end

    return metric_options
  end
end

	CODE
	run 'mkdir app/services'
	create_file 'app/services/instagram_client.haml', client_code
end

def create_instagram_account_selection
	controller_code = <<-CODE
class InstagramController < ApplicationController
  def edit
    if current_user.try(:facebook_access_token).nil?
      redirect_to root_path notice: 'Something went wrong'
    end

    @pages = current_user.instagram_pages
  end

  def update
    if current_user.update(user_params)
      redirect_to "/instagram_business/#{current_user.id}"
    else
      render :edit, notice: 'Something went wrong.  Please try again.'
    end
  end

  private

  def user_params
    params.require(:user).permit(
      :instagram_access_token, :page_id, :instagram_handle, :instagram_id
    )
  end
end
	CODE
	create_file 'app/controllers/instagram_controller.rb', controller_code

	view_code = <<-CODE
#select
  %h3 Select your Instagram Account:
  .actions
    - @pages.each do |page|
      :ruby
        hsh = {
          instagram_access_token: page['access_token'],
          page_id: page['id'],
          instagram_handle: page['instagram_handle'],
          instagram_id: page['instagram_id']
        }
      = link_to instagram_path({account: hsh}), method: :put, class: "btn btn-primary" do
        = "@\#{page['instagram_handle']}"
	CODE
	run 'mkdir app/views/instagram'
	create_file 'app/views/instagram/edit.haml', view_code
	
	route "resource :instagram, only: [:edit, :update]"

end

run "rvm use 2.5.3"
add_gems

after_bundle do
	run "spring stop"
	
	add_figaro
	add_omniauth_config
	add_bootstrap
	set_up_rspec
	set_up_css_structure
	create_user
	create_seed_data
	create_session_controller
	generate_application_controller
	add_home_page
	generate_application_helper
	set_up_flash_notification
	set_nav
	set_footer
	set_up_layout
	create_instagram_client
	create_instagram_account_selection

	# run migration 
	run 'bundle exec rails db:drop'
	run 'bundle exec rails db:create'
	run 'bundle exec rails db:migrate'
	run 'bundle exec rails db:seed'

	run 'gem install haml-rails -v 2.0.1'
	run 'HAML_RAILS_DELETE_ERB=true rails haml:erb2haml'

	run 'git add .'
	run 'git commit -m "initial commit"'

end
