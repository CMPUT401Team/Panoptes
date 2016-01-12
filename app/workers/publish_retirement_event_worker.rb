require "event_stream"

class PublishRetirementEventWorker
  include Sidekiq::Worker

  sidekiq_options queue: :data_high

  def perform(workflow_id)
    workflow = Workflow.find(workflow_id)
    EventStream.push('workflow_counters',
      project_id: workflow.project_id,
      workflow_id: workflow.id,
      subjects_count: workflow.subjects_count,
      retired_subjects_count: workflow.retired_subjects_count,
      classifications_count: workflow.classifications_count
    )
  rescue ActiveRecord::RecordNotFound
  end
end
