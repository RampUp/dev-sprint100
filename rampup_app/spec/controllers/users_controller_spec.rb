require 'spec_helper'

describe UsersController do
  context "on #new" do
    it "should create a new user object" do
      User.should_receive(:new)
      get :new
    end
  end

  context "on #create" do
    let(:params) { {
        :user => {
          :name => "bob", 
          :email => "bob@bob.com", 
          :password => "pass", 
          :password_confirmation => "pass"
          }
        } 
      }

    before :each do
      @user = User.new
      User.stub(:new).and_return(@user)
    end
    it "should create a new user" do
      User.should_receive(:new)
      post :create, params
    end
    it "should assign attributes to a user object" do
      @user.should_receive(:name=).with(params[:user][:name])
      @user.should_receive(:email=).with(params[:user][:email])
      @user.should_receive(:password=).with(params[:user][:password])
      @user.should_receive(:password_confirmation=).with(params[:user][:password_confirmation])
      post :create, params
    end
    #user validation should be tested by the user model spec, so we will force the validation to fail here.
    context "if save is successful" do
      before :each do
        User.stub(:new).and_return(@user)
      end
      it "should render the root url" do
        post :create, params
        response.should redirect_to('/')
      end
    end
    context "if save is unsuccessful" do
      before :each do
        User.stub(:save).and_return(false)
      end
      it "should flash a message to the user" do
        post :create, params
        flash.to_hash[:notice].should == 'Signed up!'
      end
      it "should redirect" do
        post :create, params
        response.should redirect_to('/')
      end
    end
  end
end