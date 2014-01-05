class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new
    if user.has_role? :admin
      can :manage, :all
    else
      can :view, 'FREE' if user.has_role? 'FREE'
      can :view, 'BASIC' if user.has_role? 'BASIC'
      can :view, 'PROFESSIONAL' if user.has_role? 'PROFESSIONAL'
      can :view, 'ENTERPRISE' if user.has_role? 'ENTERPRISE'
    end
  end
end
