#-1. Thanks#
Thanks to the awesome information in [this railscast](http://railscasts.com/episodes/250-authentication-from-scratch).
Thanks also to the great info in this (obsolete) [blog post](http://www.aidanf.net/rails_user_authentication_tutorial)

#0. Prerequisites#
This sprint assumes that you have completed the getting started tutori

#1. Creating our app#
Use rails to create a new app called 'rampup_app'. We are going to build on this app each week, much as we did with the flask apps in the first portion of the Ramp Up.

#2. Authentication#
The first section of this lab will explore how to do serious authentication in Rails. 

It may or may not be obvious, but it is important to never store a password in cleartext. There are many cryptographic hash functions available (SHA-1 and SHA-2 for instance) that will obfuscate a password by passing it through a complex series of equations. We will be using SHA-2 512; SHA-0 and SHA-1 are significantly less secure than SHA-2.

Even though passing the password into the SHA algorithm might be secure enough, it would be even better if we could guarantee that a malicious attacker with access to the database could not pretend to be an authenticated user (by just passing the sha digest in as a URL parameter). To do that, we will make use of what is known as a salt. The salt is a random string of letters and numbers that is added into the digest before storing the digest in the database. In this way, we essentially are passing the result of our previous SHA-2 into another SHA-2. 

First, though, we need to take care of the fact that Rails will send all params to the production logfile. Rails provides a method for this in the `ApplicationController::Base` code. Open up your application controller at `app/controllers/application_controller.rb` and add in the following two lines:
```
# filter out password parameters from log files
filter_parameter_logging :password
```

##Digests##
We'll refer to the result of the hashing algorithm as a digest (often you will see SHA, HMAC, hash, and digest used interchangeably). This is not the same as a Ruby hash (technically a 'hash table'), which looks like `{:key => :value}`, but refers to a cryptographic hash (actually, a 'hash function' is what generates the digest, but sometimes the output of a hash function is called a hash). The nomenclature can be a bit confusing, so we're going to agree to call the output of the SHA-2 algorithm a digest.

Open up irb and enter the following:
```
require 'digest'
Digest::SHA2.new(512)
```
This generates a 512-bit length string. Of course, we will want to create a digest from ('hash') a user's password. To demonstrate how this might work in our code, look at the result of the following:
```
secret = Digest::SHA2.new(512) << 'secret password'
```
For fun, change one character, or add one character to the end. Notice that the new digest is mostly different from the previous. If you're curious about the actual SHA-2 hashing algorithm actually works, the [Wikipedia article](http://en.wikipedia.org/wiki/SHA-2) goes to quite some depth about it.

##Code##
Honor System challenge: Tell me where this code will live. One hint if you're not sure: try to determine if this code will be used across the entire application, or for a small subset of the application, and what objects or models will need access to it.

There are actually a few 'correct' (correct meaning anything that will work) answers; we could put the code in our User model, because we will be creating digests to save Users in the database as well as to authenticate passwords; we could create a module in the `lib` folder so that we could import it into any portion of the application; we could create some helper methods in `app/helpers/application_helper.rb` so that we could just drop the methods anywhere in the application; or we could do any combination of these.

I'm going to suggest (and lay out this tutorial) assuming that we have decided to put it in the User model. This is because the User model will need to know the most about the hashing method we will write, including:
- how to generate the salt and add that to the password digest before saving that in the password field when a User is created
- how to look up the salt and apply that to the digest to validate them when a User logs in

##3. User##
There are several theories on the best way to write application code, and we're going to explore one of them here. The idea is you start with a noun and work your way out from there. For instance, I know that I will have users in my application. These users will have certain attribute (names, passwords, emails, etc.) that I will want to keep track of. I don't necessarily know all the things that users are going to have access to, but I know that I can start with the idea that a User should have to either register or log in when they get to my application.

Rather than scaffold out all the of the pieces of a user, we are going to generate each piece of the appication (migration, model, controller, views, etc.) as we go.

###Creating the Database Table###

```
rails g migration CreateUsers
```
This will create a timestamped (empty) migration file in `db/migrate/` with a name similar to `20130328035331_create_users.rb`. Open it up, and you will see something like this:
```
class CreateUsers < ActiveRecord::Migration
  def up
  end

  def down
  end
end
```
The 'up' is what will happen if we run the migration, the 'down' is what will happen if we roll back the migration. We want to create a users table, so we will use a block to do so:
```
def up
  create_table :users do |t|
    t.string :name
    t.string :email
    t.string :hashed_password
    t.string :salt

    t.timestamps
  end
end
```
This specifies that `name`, `email`, `hashed_password`, and `salt` will all be strings. If we create the table when we migrate, we should drop to the table when we roll back, so the 'down' method will look like this:
```
def down
  drop_table :users
end
```
Now, reading our migration, we can see that if we migrate up the chain, this migration will create a table called 'users' that has 4 columns we specified: name (string), email (string), hashed_password (string), and salt (string). `t.timestamps` is a special Rails method that adds a `created_at` and `modified_at` timestamp to each record in the database.

Of course, now that we've created a migration, we should create the table in the database by running `rake db:migrate`. This will create the table! Awesome!

Note: In the future, if you know what data types and names your colums will have, you can specify them in the model and it will create a migration for you, e.g.
```
rails g model CreateUsers name:string email:string salt:string hashed_password:string
```
I just wanted us to build ours from scratch this time--it's really not that bad, but can be somewhat intimidating if you've never done it before.

###Creating the Model###
It's great that we have records that we can save in the database, but Rails won't really know what to do with them until we build the model for a User, and the types of things that a User object has (attributes) and can do (methods).

Head over to `app/models/` and create a file called `user.rb`. Our user will be a class that inherits from ActiveRecord::Base, one of the core Rails modules. Your empty file should look like this:
```
class User < ActiveRecord::Base

end
```
If we had generated this file, it would already have one additional line in it:
```
attr_accessible :email, :hashed_password, :name, :salt
```
This creates three methods for each attribute, as well as 'whitelists' them for the application.

The three methods (using :email as the example):
```
def email=(arg)
  @email = email
end

def email
  @email || nil
end

def email?
  email.presence?
end
```
You might imagine there would be cases where we would want to be able to get an attribute, but not necessarily want to set it after the record has been created. For example, our salt should never change for a given user, so it would not make sense to make that available for someone to exploit (say, by changing a targeted user's salt to "").

What whitelisting means is that the attribute can be assigned via 'mass assignment.' Mass assignment just means that we can set multiple attributes at once, e.g.
```
User.new(:name => 'bob', :email => 'bob@bob.com', ...)
```
And the object will be saved. There's nothing super wrong with whitelisting, except that it can make your app more vulnerable if you have things like
```
Object.create(params[:object])
```
in your controller's `create` method. This saves you trouble by having to specify each field from the form, but opens you up for a specific type of attack.

###A quick whitelist attack example###

For example, imagine our application has 'admins,' and the form that a user completes to register passes a hash table of all the form fields into User.new, similar to
```
User.new(params[:user])
```
Then a malicious user could make a POST request to the same URL the form uses and add on a parameter for 'admin' even if no such field existed on the html form. The request might look like
```
curl -x http://www.yourapplication.com/users/new?name=hacker&email=hacker@hacker.com&admin=1
```
`params[:user]` is pulled from the POST request as `{:name => 'hacker', :email => 'hacker@hacker.com', :admin => 1}` and a new admin user is created.

There are many ways to guard against this, up to and including having a manual process for creating administrators, but to keep things simple all we would do in this case is mark 'admin' as `:attr_protected.` This essentially prevents any kind of external form-based (or POST) access to this attribute.

Another way to protect against it is to call out specific parameters:
```
#in the controller code...
def create
  u = User.new
  u.email = params[:user][:email]
  u.name = params[:user][:name]
  u.password = params[:user][:password]
  u.password_confirmation = params[:user][:password_confirmation]
  u.save
end
```

We don't have an admin column, but we do have a salt. Remember that the point of the salt is to make it so that if a hacker gains access to our database he cannot just send the `hashed_password` value through a login field, because the salt is added to the password digest before it is written to the database. If, however, an attacker could change the salt to anything (for example, ""), then it would defeat the purpose of having a salt in the first place. Therefore, we probably want to protect our salt column in the following way:

```
class User < ActiveRecord::Base
  attr_accessible :email, :name

  attr_accessor :password, :password_confirmation
end
```
But wait! What happened to hashed_password? That was the name of the column, right? What's this 'password' and 'password_confirmation' business?

Let me explain...

In the form it will make the most sense to give a new user a password and password confirmation field. Since we don't want the view to house the code that creates the hashed password, the form will just pass those values in to the controller as `params[:user][:password]` and `params[:user][:password_confirmation]`, respectively.

The controller is another option for putting in the code to transform password into hashed_password and then pass that directly to the model. However, we wouldn't want a specific controller (whether it is the users_controller, posts_controller, or some other random controller that requires user authentication) to own all the logic associated, so it makes sense to just let the user model handle all authentication related tasks.

By using `attr_accessor` to create `:password`, we are taking advantage of the fact that Rails will create an instance variable, `@password`, a setter method (`password=`), and a getter method (`password`). However, we want to create a hashed_password and save that, and **definitely** don't want to save the actual password anywhere.

Fortunately, there is an easy solution. We will simply override the setter method for `password` with our own method that creates a salt and salted password digest.

I would like you to take a stab at creating the `password=` method in user. A starting point might be:
```
def password=(pass)
  @password = pass
end
```

From here, you will need to have a line that creates the salt (and assigns it to `self.salt`) and a line that creates the hashed_password (and assigns it to `self.hashed_password`).

If you're not sure how to create a method that will produce a salt from numbers and letters (lowercase and uppercase), I encourage you to experiment in irb with the following:
```
('a'..'z').to_a
('A'..'Z').to_a
(0..9).to_a
```
and look up how to combine arrays...you will most likely want to use a random number generator to select the index of the master array, and thus give you a random character for your salt. Let's decide that our salt will be 10 alphanumeric characters long.

If you're not sure about the hashing method, go ahead and at the top of your user.rb file enter
```
require 'digest'
```
and experiment with
```
Digest::SHA2.hexdigest("some_string")
```
Remember that you will want to hash the password and the salt together.

For the curious, the other two arguments against spreading this code around are:
1. A programming concept called 'the law of demeter', which basically states that each model should only 'know' about the structure / interfaces of its direct neighbors
2. To avoid cluttering and spreading of code to different objects and classes, so that future changes are easy to make in one place, versus being distributed throughout the application

###Model Validation###
For any model we should have some validations on required params. For instance, it wouldn't make much sense to have a user who had no email, or no name, would it?

Add validation to ensure that any user has a name, password, password_confirmation, hashed_password, email, and salt.

Also add validation to make sure password and password_confirmation match (Hint: there is a rails validation helper for this).

Don't forget to validate that the email is unique, so that you cannot have multiple users with the same email!

If you want to add a regex to the email validation, you may, but realize that any regex you write is bound to have holes in it, and that you can use the html 'email' input tag to do some of this validation for you. If you're really into regexes, though, go for it! Also note that there are great tools for helping you test your regex, such as [rubular](http://rubular.com/).

##4. Testing##
We have a model, that means we should write tests!

The reason why tests are so important is because they are the only way to tell if you've broken something deep inside your app by adding a new feature, deleting some old code, or refactoring/redesigning your application. In general, tests should cover the interfaces (inputs and outputs), validations, and major functionality of your code. This way you don't have to find out the hard way if something breaks (for instance, by visiting the `/posts/` page and seeing nothing!).

We're going to be using the testing gem `rspec-rails`.

Open the gemfile and delete all the commented text; this will help with our application readability before heading over to [rubygems](http://rubygems.org) and looking up rspec-rails.

Rspec-rails is a gem that will allow us to write tests for each of our controllers, models, and views. Add rspec to the gemfile as shown on the rubygems page for the gem and bundle install. Follow the directions on the rspec-rails documentation page to install the gem.

Enter the `spec/models` directory and open the `user_spec.rb` file if it exists. If it doesn't exist, create it. You should see
```
require 'spec_helper'

describe User do
  pending "add some examples to (or delete) #{__FILE__}"
end
```

###Test-Driven Development###
Let's add a few specs to drive the fleshing out of our User model. I'm going to do this one, but as you add models, controllers, and views, you should be writing specs to cover how they function to prevent against breaking them with future features.

We can imagine that we'd want to be able to
1. look up a user by their email
2. given a user's digested password, add in the salt and use that to validate a user's login
3. create a salt for a user when they are first created
4. validate a new user object before saving it

This is what a spec for these characteristics might look like:
```
require 'rspec_helper'

describe User do
  before :each do
    @user = User.new
  end
  context "validation" do
    before :each do
      @user = User.new
    end
    it "should verify the presence of name, email, password, password_confirmation, hashed_password, and salt" do
      @user.name = "bob"
      @user.password = "password"
      @user.password_confirmation = "password"
      @user.email = "homer@thesimpsons.com"
      @user.salt = "salt1234"
      @user.should be_valid
    end
    it "should make sure passwords match" do
      @user.name = "bob"
      @user.password = "password"
      @user.password_confirmation = "wordpass"
      @user.email = "homer@thesimpsons.com"
      @user.salt = "salt1234"
      @user.should_not be_valid
    end
    it "should not allow mass assignment of salt" do
      lambda {User.new(:name => "homer simpson", :password => "password", :password_confirmation => "password", :email => "homer@simpsons.com", :salt => "salt1234")}.should raise_error
    end
    ['name', 'email', 'password', 'password_confirmation'].each do |attr|
      it "should not be valid when missing #{attr}" do
        (['name', 'email', 'password', 'password_confirmation'] - [attr]).each do |attribute|
          @user.send(attribute+'=', 'foo')
        end
        @user.should_not be_valid
      end
    end
  end

  context "methods" do
    before :each do
      @user = User.new
      @user.name = 'bob'
      @user.email = 'bob@bob.com'
      @user.password = 'password'
      @user.password_confirmation = 'password'
      @user.save
    end
    it "should allow us to find a user by email" do
      User.find_by_email(@user.email).should == @user
    end
    it "should have an authenticate method" do
      User.methods.include?("authenticate")
    end
    it "should authenticate a valid password" do
      User.authenticate("#{@user.email}", "password").should == @user
    end
    it "should not authenticate an invalid password" do
      User.authenticate("#{@user.email}", "bad_password").should_not == @user
    end
  end
end
```
For now, focus on getting the tests to pass. You can run the tests (assuming you've installed rspec) by typing `rake`. 

If you spend more than an hour trying to get the tests to pass, you can just copy the `user.rb` file from the `examples` folder in the repository.

##5. Views##

Let's craft a simple login page. First delete the `index.html` file from your `public/` directory.

You may remember that we need to specify routes in our application (just like in flask or django). Add the following to your `routes.rb`:
```
RampupApp::Application.routes.draw do  
  get "log_out" => "sessions#destroy", :as => "log_out"
  get "log_in" => "sessions#new", :as => "log_in"
  get "sign_up" => "users#new", :as => "sign_up"
  root :to => "users#new"
  resources :users
  resources :sessions
end
```
I'll ask you to trust me on the resources and the get routes...for now we will concern ourselves with stepping through the application.

Save the file, and (double-check to make sure `public/index.html` is gone!) start the rails server
```
rails s
```
Alternatively, you can add the `-d` flag to start it in detached mode, which means it will run in the background
```
rails s -d
```
of course this means you'll have to hunt down the process later and kill it, and you won't see log information, so pick whichever one you feel fits your style more.

If you open `localhost:3000` in your web browser, you should see an error message along the lines of 
```
Routing Error

uninitialized constant UsersController
Try running rake routes for more information on available routes.
```
This is excellent! This tells us exactly what to do.

###Users Controller###
We are going to create `users_controller.rb` next. If you guessed that it will live in `app/controllers/users_controller.rb` then you are correct! In keeping with the general theme of this lab, let's start from scratch :)

```
class UsersController << ApplicationController

end
```

Refresh the page in your browser, and behold! Rails will tell you exactly what to do next!

```
Unknown action

The action 'new' could not be found for UsersController
```

So let's make a new action:
```
def new
  @user = User.new
end
```
I bet you can guess that I'll suggest refreshing the page again...you are correct! This is a great technique for developing because it prevents you from getting sucked down a rabbit hole where you build out a feature completely before discovering a fundamental assumption was incorrect, or a fundamental step was missed.

Now you should see
```
Template is missing

Missing template users/new, application/new with {:locale=>[:en], :formats=>[:html], :handlers=>[:erb, :builder, :coffee]}. Searched in: * "/Users/ddieker/projects/dev-sprint9/rampup_app/app/views"
```

So, you guessed it, we are going to create a template. Create `views/users/new.html.erb`.

If you refresh now, you will see no error messages--Rails is happy (and you should be too!)!. Happy, but not satisfied; after all, this is meant to create a new user. To create a new user, we are going to need a series of parameters we can use to create that user, and the best way to gather these is probably through a form.

In your `new.html.erb` file, enter the following:
```
<h2>Register as a new user</h2>
<%= form_for @user do |f|%>
  <p>
    <%= f.label :name %><br />
    <%= f.text_field :name %>
  </p>
  <p>
    <%= f.label :email %><br />
    <%= f.email_field :email %>
  </p>
  <p>
    <%= f.label :password %><br />
    <%= f.password_field :password %>
  </p>
  <p>
    <%= f.label :password_confirmation %><br />
    <%= f.password_field :password_confirmation %>
  </p>
  <p class="button"><%= f.submit %></p>
<% end %> 
```
`form_for` is a Rails helper method that takes an object (and a number of other optional arguments) and uses that object as the key for a hash. Essentially, you can think of `form_for` as adding `params[:user]` (remember the `@user` is passed in by the controller, and represents `User.new`). Each `form_field` we create for user adds that key to the user hash. The above code will create:
```
params[:user][:name]
params[:user][:email]
params[:user][:password]
params[:user][:password_confirmation]
```

Go ahead and refresh the page, and you should see a form that has the fields that we coded for. If you fill out the form and hit the submit button, you will see a new error message (this is great! It means progress!!)

```
Unknown action

The action 'create' could not be found for UsersController
```

So we've learned that by default, the Ruby form_helper's submit button will send us to the `#create` method in the `users_controller`. Ruby has told us that method doesn't exist, so let's go create it!

In UsersController, we will want to assign the various parts of `params[:user]`. Remember that we should avoid mass assignment to protect against exploits, and that we will need to call `@user.save` once we finish assigning all the attributes.

Of course, it's always good to handle the case where your model object might be invalid, so let's be conservative and wrap the save statement in an if/else block.
```
def create
  @user = User.new
  #the methods to assign values go here
  if @user.save
    redirect_to root_url, :notice => "Signed up!"
  else
    flash.now.alert = "Invalid email or password"
    render "new"
  end
end
```
The flash method may look familiar to you--it, and `:notice` are both very similar to the flashed_messages method that flask provides; essentially these messages will be presented to the user. If the `@user` object saves properly, we will be redirected to the `root_url` as specified in the `routes.rb` file. If, however, the save fails (meaning the `@user` object is invalid), we want to redirect to the sign up form.

Of course, you may notice that after a save we don't see the flashed message, nor do we see anything different after we create an account. To do that we're going to have to add something to our `new.html.erb` and our `application.html.erb` layout:
```
#in app/views/users/new.html.erb
<%= form_for @user do |f|
  <% if @user.errors.any? %>
    <div class="error_messages">
      <strong>Form is invalid</strong>
      <ul>
        <% for message in @user.errors.full_messages %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>
  ...
<% end %>
```

A layout in Rails is a template within which all other templates are rendered. It is possible to have multiple layouts (for instance, one for admins and one for users, or maybe different layouts for different areas of the application). Basically wherever the `<%= yield %>` statement sits is where the views will be rendered inside the layout.

```
#in app/views/layouts/application.html.erb above the `yield`
<% flash.each do |name, msg| %>
  <%= content_tag :div, msg, :id => "flash_#{name}" %>
<% end %>
```

##6. Sessions##
We have a way for users to sign up, but not a way for them to sign in! Enter sessions. A session helps us identify the current user. Much as any other site you log in to is able to remember who you are even as you navigate links within the site, or leave and then come back, we want our application to create a session when a user authenticates (logs in).

The best way to manage a session, is with a session controller.

Go ahead and create the sessions_controller.rb file in app/controllers/.

Our sessions controller is going to look like this:
```
class SessionsController < ApplicationController
  def new
  end

  def create
    user = User.authenticate(params[:email], params[:password])
    if user
      session[:user_id] = user.id
      redirect_to root_url, :notice => "Logged in!"
    else
      flash.now.alert = "Invalid email or password"
      render "new"
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_url, :notice => "Logged out!"
  end
end
```
You may remember from our routes file that we mapped Rails' 'sign_in' path to the 'sessions#new' action; essentially saying that anytime we link to the 'sign_in_path' in Rails, we want to point to the 'new' method in sessions_controller.rb.

You may also remember, from our work in the UsersController, that any forms in a view for the `new` action of a controller will submit to the `create` action of that same controller (of course, you can override this, but we have no need to).

So if we look at `sessions#create`, we can see that it takes an :email and :password parameter, and uses the `User.authenticate` method that we created in our model to determine if a valid user is attempting to log in. If the user authenticates, we set the session variable :user_id to be the user's id, and send them to the root url with the notice that they have authenticated successfully.

If, however, the email and password combination fail the authentication method, we flash an alert that the email and password were invalid and redirect to the registration form.

Finally if a user logs out, we will want to destroy the session, and `#destroy` does just that, setting the session variable for :user_id to `nil` and redirecting to the root url with a "Logged out!" notice.

But wait! We have no way of accessing these methods, no login form!

If we want to match the login form to the SessionsController's `new` method, it stands to reason that we will need a template in /app/views/sessions...and furthermore, you've probably already guessed that we'll call it `new.html.erb` :)

I'm going to include the code below because we're going to do something special with this form.

Rails form helpers typically rely upon an object to help them determine what to call the parameters they send back to the controller. In this case we simply specify the sessions_path, which is generated by our `resources :sessions` line in the `routes.rb` file, and tells the form that the submit_tag will point to `localhost:3000/root_url/sessions/create`.

Everything else, though, you'll see is very similar. There is a `password_field_tag` and a `text_field_tag`, which are in principal the same as the `f.text_field` and `f.password_field`. The only difference (which you may have noticed already) is that in the `app/users/new.html.erb` form when we go through the form_tag block we assign the empty object, `@user`, to the variable |f|, so all the input fields we add within the form have that object as context. In this case, there is no object to pass through because we are just targeting a url, so we will use the tag methods instead.

```
<h1>Log in</h1>

<%= form_tag sessions_path do %>
  <p>
    <%= label_tag :email %><br />
    <%= text_field_tag :email, params[:email] %>
  </p>
  <p>
    <%= label_tag :password %><br />
    <%= password_field_tag :password %>
  </p>
  <p class="button"><%= submit_tag "Log in" %></p>
<% end %>
```

Okay, let's assume that this works for now. If we go back to the root url, we don't really have a way of logging in, we only see the new user creation form. The way we're going to tackle this is not by editing each view, which will be tedious, but instead by editing the layout, so that on any page we visit, we are either presented with `log in` and `sign up` links, or with a `log out` link.

Another method to writing code is to 'write the code that we want to have' rather than writing the code that works right now. This helps us do some design in our heads when another person might not be around to bounce our ideas off of. For instance, we might imagine a section of the application.html.erb layout to look like this:
```
<div id="user_nav">
  <% if current_user %>
    Logged in as <%= current_user.email %>.
    <%= link_to "Log out", log_out_path %>
  <% else %>
    <%= link_to "Sign up", sign_up_path %> or
    <%= link_to "log in", log_in_path %>
  <% end %>
</div>
```
This logic either presents the user with a 'log out' link if they exist as a `current_user`, or presents them with links to `sign up` or `log in` if there is no `current_user`.

I bet you can probably imagine what `current_user` accesses...

Yup, we're going to use the session we've created! We're going to create a helper method of our own that we can use throughout our application. The way we'll do that is by placing this method in the ApplicationController, the class that all of our other controllers inherit from.

```
helper_method :current_user

private

def current_user
  @current_user ||= User.find(session[:user_id]) if session[:user_id]
end
```

We privatize this method for security, so that no outside controller or method can call it. Private methods can only be called from within the class in which they reside, or by explicitly using the :send method and passing the method name in as an argument.

If we step through what current_user actually does, it checks to see what the result of `User.find(session[:user_id])` is if `session[:user_id]` is present. The way that we defined sessions in the `SessionsController`, `session[:user_id]` is only set upon the completion of a successful login.

Refresh your application, and go through the steps of logging in and logging out. Verify that the application works properly. If you encounter issues, please ask on Piazza so that others can leverage the answers to your questions.

Finally, if you get to the point where you feel you are stuck, take a peek through the rampup_app folder in the repository, or reach out directly to myself or another TA (on facebook, email, or piazza).

#Feedback#
Please send any feedback to ddieker (at) gmail (dot) com. I would love to hear:
1) how far you got
2) how appropriate / inappropriate you felt the complexity and amount of assignments was (you might have different answers for each!)
3) what you wished I had explained in the lab (but you had to go out and find out on your own)
4) any remaining questions you have after completing the lab---I will try and address these either in the next lab or the next time I or one of the other TMs sees you.

Thanks!