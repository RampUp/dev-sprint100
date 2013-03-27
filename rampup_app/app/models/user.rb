require 'digest'

class User < ActiveRecord::Base
  attr_accessible :email, :name

  validates_presence_of :email, :name, :password, :password_confirmation, :hashed_password, :salt
  validates_confirmation_of :password

  validates_uniqueness_of :email

  attr_accessor :password, :password_confirmation

  def password=(password)
    @password = password
    self.salt = User.make_salt
    self.hashed_password = User.encrypt(@password, self.salt)
  end

  def self.authenticate(email, password)
    user = User.find_by_email(email)
    return nil if user.nil?
    return user if user.hashed_password == User.encrypt(password, "#{user.salt}")
    nil
  end

  private

  def self.encrypt(password, salt)
    Digest::SHA2.hexdigest("#{password}" + "#{salt}")
  end

  def self.make_salt
    array = (0..9).to_a + ("a".."z").to_a + ("A".."Z").to_a
    string = ''
    10.times {string << array[rand(array.length - 1)].to_s}
    string
  end
end