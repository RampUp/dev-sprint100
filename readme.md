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

##User##
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

Note: In the future, if you know what data types and names your colums will have, you can specify them in the migration, e.g.
```
rails g migration CreateUsers name:string email:string salt:string hashed_password:string
```
and the migration will pretty much be created for you! I just wanted us to build it from scratch this time--it's really not that bad, but can be somewhat intimidating.

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
You might imagine there woudl be cases where we would want to be able to get an attribute, but not necessarily want to set it after the record has been created. For example, our salt should never change for a given user, so it would not make sense to make that available for someone to exploit (say, by changing a targeted user's salt to "").

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

For security - keep the hashing algorithm and salt creation inside the user
For code sanity - objects should know the bare minimum about other objects
For code sanity - We should not clutter other parts of code (e.g. password change method, signup method) with code that could be in just the User model

Fortunately, there is a way to use password and password_confirmation without actually persisting them to the database.




###Model Validation###
For any model we should have some validations on required params. For instance, it wouldn't make much sense to have a user who had no email, or no name, would it?

Add validation to ensure that any user has a name, password, password_confirmation, hashed_password, email, and salt.

Also add validation to make sure password and password_confirmation match (Hint: there is a rails validation helper for this).

If you want to add a regex to the email validation, you may, but realize that any regex you write is bound to have holes in it, and that you can use the html 'email' input tag to do some of this validation for you. If you're really into regexes, though, go for it! Also note that there are great tools for helping you test your regex, such as [rubular](http://rubular.com/).

##Testing##
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
1) look up a user by their email
2) given a user's digested password, add in the salt and use that to validate a user's login
3) create a salt for a user when they are first created
4) validate a new user object before saving it

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