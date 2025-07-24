# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    if user.persisted?
      can %i[like rate comment], Product
      can :manage, :cart
      can :create, Payment
      can :show, Payment, order: { user_id: user.id }
      can %i[create me], Order
      can %i[read cancel], Order, user_id: user.id
    end

    if user.admin?
      can :manage, :all
    elsif user.moderator?
      can :read, :all
      can :manage, User, id: user.id
      can %i[update create], Product, user_id: user.id
    elsif user.regular?
      can :read, :all
      can :manage, User, id: user.id
    end
  end
end
