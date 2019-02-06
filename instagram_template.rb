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

html, body {
	font-family: $serif-font;
	font-size: 16px;
	background-color: #F3EFEC;
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
class SessionController < ApplicationController
	def new
		redirect_to 'auth/instagram_business', status: 301
	end
	def create
		user = User.create_from_omniauth(auth_hash)
		session[:user_id] = user.id.to_s
		redirect_to root_path, success: "Signed In"
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
	route "get '/auth/:provider/callback', to: 'session#create'"
	route "get '/logout', to: 'session#destroy'"
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

		# Site Meta
		%title= content_for?(:title) ? content_for(:title) : title
		%meta{content: "text/html; charset=UTF-8", "http-equiv": "Content-Type"}
		%meta{content: description, name: "description"}
		%meta{content: "", name: "keywords"}
		%meta{content: "index, nofollow", name: "robots"}
		%meta{content: "5 days", name: "revisit-after"}
		%meta{content: "width=device-width, initial-scale=1", name: "viewport"}
		
		# Favicons 
		%link{href: "/favicon.ico", rel: "shortcut icon", type: "image/x-icon"}
		%link{href: "/favicon.ico", rel: "icon", type: "image/x-icon"}

		# OG TAGS
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
    = javascript_include_tag 'application', 'data-turbolinks-track': 'reload'
	%body
		= render "layouts/partials/flash"
		= render "layouts/partials/nav"
		= yield
		= render "layouts/partials/footer"
	CODE
	run 'rm -rf app/views/layouts/application.html.erb'
	create_file 'app/views/layouts/application.haml', layout
end
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
	set_up_flash_notification
	set_nav
	set_footer
	set_up_layout

	# run migration 
	run 'bundle exec rails db:drop'
	run 'bundle exec rails db:create'
	run 'bundle exec rails db:migrate'
	run 'bundle exec rails db:seed'

end
