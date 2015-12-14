class EnqueueSubjectQueueWorker
  include Sidekiq::Worker

  sidekiq_options congestion: Panoptes::SubjectEnqueue.congestion_opts.merge({
    key: ->(workflow_id, user_id, subject_set_id) {
      "user_#{ workflow_id }_#{user_id}_#{subject_set_id}_subject_enqueue"
    }
  })

  attr_reader :workflow, :user, :subject_set_id, :limit, :strategy

  def perform(workflow_id, user_id=nil, subject_set_id=nil, limit=SubjectQueue::DEFAULT_LENGTH, strategy=nil)
    @workflow = Workflow.find(workflow_id)
    @user = User.find(user_id) if user_id
    @subject_set_id = subject_set_id
    @limit = limit
    @strategy = strategy

    begin
      subject_ids = selected_subject_ids.compact
    rescue Subjects::CellectClient::ConnectionError
      subject_ids = default_strategy_ids
    end

    unless subject_ids.empty?
      SubjectQueue.enqueue(workflow, subject_ids, user: user, set_id: subject_set_id)
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  private

  def selected_subject_ids
    case strategy
    when :cellect
      Subjects::CellectClient.get_subjects({}, workflow.try(:id), user.try(:id), subject_set_id, limit)
    else
      default_strategy_ids
    end
  end

  def default_strategy_ids
    Subjects::PostgresqlSelection.new(workflow, user)
    .select(limit: limit, subject_set_id: subject_set_id)
  end
end
