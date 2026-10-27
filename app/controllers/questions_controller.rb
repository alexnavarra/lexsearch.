class QuestionsController < ApplicationController
  limit_llm_requests to: 10, only: :create
  def index
    @question = Question.new(params.permit(*Question::FILTERS))
    @questions = recent
  end

  def show
    @question = Question.find(params[:id])
  end

  def create
    @question = Question.new(params.expect(question: [ :text, *Question::FILTERS ]))

    if @question.save
      AskQuestionJob.perform_later(@question)
      redirect_to @question
    else
      @questions = recent
      render :index, status: :unprocessable_content
    end
  end

  private

  def recent = Question.order(created_at: :desc).limit(20)
end
