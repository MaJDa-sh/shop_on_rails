# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def dial_2fa_code(user, code)
    @user = user
    @cide = code
    mail(to: @user.mail, subject: 'Your 2FA code')
  end

  def dial_activation_code(user, code)
    @user = user
    @cide = code
    mail(to: @user.mail, subject: 'Activation of yout account')
  end

  def dial_reset_code(user, code)
    @user = user
    @cide = code
    mail(to: @user.mail, subject: 'Your reset code')
  end
end
