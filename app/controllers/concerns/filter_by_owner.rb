module FilterByOwner
  extend ActiveSupport::Concern

  included do
    before_action :add_owner_ids_to_filter_param!, only: :index
  end
  
  def add_owner_ids_to_filter_param!
    if owner_filter = params.delete(:owner).try(:split, ',')
      groups = UserGroup.where(name: owner_filter).select(:id)
      @controlled_resources = controlled_resources
                              .joins(:access_control_lists)
                              .where(access_control_lists: {user_group: groups})
                              .where.overlap(access_control_lists: { roles: ["owner"] })
    end
  end
end