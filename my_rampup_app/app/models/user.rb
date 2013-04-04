require 'digest'

class User < ActiveRecord::Base

	attr_accessible :email, :name

	attr_accessor :password, :password_confirmation
	validates_presence_of :password, :email, :name, :salt, :password_confirmation, :hashed_password
	validates_confirmation_of :password

	def password=(pass)
		@password = pass
		salt_array = ('A'..'Z').to_a.concat((0..9).to_a).concat(('a'..'z').to_a)
		salt = ''
		10.times {salt += salt_array[rand(salt_array.size())].to_s}

		self.hashed_password= User.encrypt(@password, salt)
		self.salt = salt
	end
	def self.authenticate(email, password)
		user = User.find_by_email(email)
		return nil if user.nil?
		return user if user.hashed_password == User.encrypt(password, "#{user.salt}")
		nil
	end
	def self.encrypt(password,salt)
		Digest::SHA2.hexdigest("#{password}" + "#{salt}")
	end
end