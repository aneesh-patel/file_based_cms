ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end
  
  def setup
    FileUtils.mkdir_p(data_path)
  end
  
  def teardown
    FileUtils.rm_rf(data_path)
  end
  
  def admin_session
    { "rack.session" => { user: "admin" } }
  end
  
  def session
    last_request.env["rack.session"]
  end
  
  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end
  
  def test_home
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end
  
  def test_viewing_text_document
    create_document "history.txt", "Ruby 0.95 released"
    
    get "/history.txt", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end
  
  def test_viewing_md_document
    create_document "about.md", "<h1>Ruby is...</h1>"
    
    get "/about.md", {}, admin_session
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end
  
  def test_document_not_found
    get "/notafile.ext", {}, admin_session # Attempt to access a nonexistent file
  
    assert_equal 302, last_response.status # Assert that the user was redirected
    assert_equal "notafile.ext does not exist.", session[:error]
  end
  
  def test_editing_document
    create_document("changes.txt", "some code")
    
    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    post "/changes.txt", {file_content: "new content"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated!", session[:success]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end
  
  def test_view_new_document_form
    get "/new/create", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_create_new_document
    post "/new/create", {newdoc: "test.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been created!", session[:success]

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_without_filename
    post "/new/create", {newdoc: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end
  
  def test_deleting_document
    create_document("test.txt")

    post "/test.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:success]

    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end
  
  # test/cms_test.rb
  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:success]
    assert_equal "admin", session[:user]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:user]
    assert_includes last_response.body, "Invalid credentials"
  end

  def test_signout
    get "/", {}, {"rack.session" => { user: "admin" } }
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal "You have been signed out!", session[:success]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end
end

