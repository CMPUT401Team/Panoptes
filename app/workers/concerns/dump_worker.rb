module DumpWorker
  extend ActiveSupport::Concern

  included do
    include ActiveSupport::Callbacks
    define_callbacks :dump
    attr_reader :project
  end

  def perform(project_id, medium_id=nil, requester_id=nil, *args)
    if @project = Project.find(project_id)
      @medium_id = medium_id
      begin
        run_callbacks :dump do
          perform_dump(*args)
          upload_dump
        end
      ensure
        cleanup_dump
      end
    end
  end

  def upload_dump
    to_gzip
    write_to_s3
    set_ready_state
  end

  def cleanup_dump
    FileUtils.rm(csv_file_path)
    FileUtils.rm(gzip_file_path)
  end

  def dump_target
    @dump_target ||= self.class.to_s.underscore.match(/\A(\w+)_dump_worker\z/)[1]
  end

  def dump_type
    "project_#{dump_target}_export"
  end

  def temp_file_path
    "#{Rails.root}/tmp/#{project_file_path.join("_")}"
  end

  def csv_file_path
    "#{Rails.root}/tmp/#{project_file_path.join("_")}.csv"
  end

  def gzip_file_path
    "#{Rails.root}/tmp/#{project_file_path.join("_")}.gz"
  end

  def project_file_path
    [dump_type, project.owner.login, project.display_name]
      .map{ |name_part| name_part.downcase.gsub(/\s/, "_")}
  end

  def medium
    @medium ||= @medium_id ? load_medium : create_medium
  end

  def set_ready_state
    medium.metadata["state"] = 'ready'
    medium.save!
  end

  def create_medium
    Medium.create!(content_type: "text/csv",
                   type: dump_type,
                   path_opts: project_file_path,
                   linked: project,
                   metadata: { state: 'creating' },
                   private: true)
  end

  def load_medium
    m = Medium.find(@medium_id)
    metadata = m.metadata.merge("state" => "creating")
    m.update!(path_opts: project_file_path, private: true, content_type: "text/csv", metadata: metadata)
    m
  end

  def write_to_s3
    medium.put_file(gzip_file_path, compressed: true)
  end

  def to_gzip
    Zlib::GzipWriter.open(gzip_file_path) do |gz|
      gz.mtime = File.mtime(csv_file_path)
      gz.orig_name = File.basename(csv_file_path)
      File.open(csv_file_path) do |fp|
        while chunk = fp.read(16 * 1024) do
          gz.write(chunk)
        end
      end
      gz.close
    end
  end
end
