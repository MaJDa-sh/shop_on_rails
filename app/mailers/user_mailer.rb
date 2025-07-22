class UserMailer < ApplicationMailer
  def send_2fa_code(user, code)
    @user = user
    @cide = code
    mail(to: @user.mail, subject: '')
  end

  def send_activation_code(user, code); end
  def send_verification_code(user, code); end
  def send_reset_code(user, code); end
end
