# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    if user.admin?
      can :manage, :all
    elsif user.moderator?
      can :read, :all
      can :update, Product, user_id: user.id
    elsif user.regular?
      can :read, :all
    else

    end
  end
end
