class DocumentsController < ApplicationController
  before_action :set_document, only: %i[show edit update destroy]

  def index
    @documents = Document.order(:topic, :title)
    @documents = @documents.where(topic: params[:topic]) if params[:topic].present?
  end

  def show; end

  def new
    @document = Document.new
  end

  def create
    @document = Document.new(document_params)
    file = params.dig(:document, :file)
    return render_too_large if file.present? && file.size > DocumentImport::MAX_BYTES

    if file.present?
      @document.source_format = DocumentImport.format_for(file.original_filename)
      @document.title = File.basename(file.original_filename, ".*").tr("_", " ").squish if @document.title.blank?
    end
    raw = file.present? ? file.read : params.dig(:document, :raw)

    if DocumentImport.new(@document, raw:, filename: file&.original_filename).call.persisted?
      redirect_to @document, notice: "Документ загружен."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  # Body is edited as Markdown, whatever the original format was
  def update
    @document.assign_attributes(document_params)
    DocumentImport.new(@document, raw: params.dig(:document, :body), format: "markdown").call

    if @document.errors.none?
      redirect_to @document, notice: "Документ обновлён."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @document.destroy!
    redirect_to documents_path, notice: "Документ удалён.", status: :see_other
  end

  private

  # Checked before reading: the upload is already on disk, no need to load it into memory
  def render_too_large
    @document.errors.add(:base, "Файл больше #{DocumentImport::MAX_BYTES / 1.megabyte} МБ")
    render :new, status: :unprocessable_content
  end

  def set_document
    @document = Document.find(params[:id])
  end

  def document_params
    params.expect(document: %i[title kind topic language source_format source_url])
  end
end
