require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require 'yaml'
require 'bcrypt'


def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def root_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/", __FILE__)
  else
    File.expand_path("../", __FILE__)
  end
end

# Makes sure user is logged in or redirects back to home and sets error message
def verify_credentials
  if logged_in? == nil
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

# Enable Sessions
configure do 
  enable :sessions
  set :session_secret, 'secret'
end

# Checks credentials of login
def correct_login?(username, password)
  users_directory = File.join(root_path, "users.yaml")
  acceptable_users = YAML.load(File.read(users_directory))
  ref_password = BCrypt::Password.new(acceptable_users[username])
  acceptable_users.key?(username) && ref_password == password
end

# Render Homepage
get "/" do
  @path = File.join(data_path, "*")
  @files = Dir.glob(@path).map do |path|
    File.basename(path)
  end
  erb :home
end

# Handle signout POST request
post "/users/signout" do
  verify_credentials
  session.delete(:user)
  session[:success] = "You have been signed out!"
  redirect "/"
end

# Render Sign-In Page
get "/users/signin" do
  erb :signin, layout: :signin_layout
end

# Handle login POST request
post "/users/signin" do
  username = params[:username]
  password = params[:password]
  if correct_login?(username, password)
    session[:user] = username
    session[:success] = "Welcome!"
    redirect "/"
  else
    status 422
    session[:error] = "Invalid credentials."
    erb :signin, layout: :signin_layout
  end
end

# Load file with regards to type of file
def load_file(path)
  if path.split(".").last == "md"
    erb render_markdown(File.read(@path))
  else
    headers["Content-Type"] = "text/plain"
    File.read(@path)
  end
end

# Open file
get "/:file" do
  verify_credentials
  @file_name = params[:file]
  @path = File.join(data_path, @file_name)
  
  if error = error_no_file(@path)
    session[:error] = error
    redirect "/"
  else
    load_file(@path)
  end
end

# Edit a file page
get "/:file/edit" do
  verify_credentials
  @file_name = params[:file]
  @path = File.join(data_path, @file_name)
  @content = File.read(@path)
  erb :edit
end

# Process edit POST request
post "/:file" do
  verify_credentials
  @file_name = params[:file]
  @path = File.join(data_path, @file_name)
  
  IO.write(@path, params[:file_content])
  session[:success] = "#{@file_name} has been updated!"
  
  redirect "/"
end

# Checks to see if file exists
def error_no_file(path)
  if File.exist?(path)
    nil
  else
    "#{File.basename(path)} does not exist."
  end
end

# Render Create a New Document Page
get "/new/create" do
  verify_credentials
  erb :new
end

# Handling create new list POST request
post "/new/create" do
  verify_credentials
  if error = error_for_name(params[:newdoc])
    status 422
    session[:error] = error
    erb :new
  else
    File.open(File.join(data_path, params[:newdoc]), "w") do |file|
      file.write("")
    end
    session[:success] = "#{params[:newdoc]} has been created!"
    redirect "/"
  end
end

# Checks to make sure a name has been entered and creates error string if not
def error_for_name(name)
  if name.size < 1
    "A name is required"
  end
end

# Handles deleting a document POST request
post "/:file/delete" do
  verify_credentials
  file = @params[:file]
  path = File.join(data_path, file)
  File.delete(path)
  session[:success] = "#{file} has been deleted."
  redirect "/"
end

helpers do
  # Render text in markdown
  def render_markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(text)
  end
  
  # Check to see if a user is logged in or not
  def logged_in?
    true unless session[:user].nil?
  end
  
end