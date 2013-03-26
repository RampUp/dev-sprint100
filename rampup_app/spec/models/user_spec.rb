require 'spec_helper'

describe User do
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
