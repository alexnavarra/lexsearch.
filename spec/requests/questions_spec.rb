require "rails_helper"

RSpec.describe "Questions", type: :request do
  it "creates a question with filters and queues the answer" do
    expect {
      post questions_path, params: { question: { text: "hnsw vs ivfflat", topic: "postgresql", kind: "", language: "" } }
    }.to have_enqueued_job(AskQuestionJob)

    question = Question.last
    expect(question.filters).to eq("topic" => "postgresql")
    expect(response).to redirect_to(question)
  end

  it "limits questions per minute, since each one costs an LLM call" do
    10.times { post questions_path, params: { question: { text: "q" } } }
    expect(Question.count).to eq(10)

    post questions_path, params: { question: { text: "one too many" } }

    expect(Question.count).to eq(10)
    expect(flash[:alert]).to include("Слишком много запросов")
    travel(61.seconds) { post questions_path, params: { question: { text: "later" } } }
    expect(Question.count).to eq(11)
  end

  it "re-renders the form for a blank question" do
    post questions_path, params: { question: { text: "" } }

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "shows a pending question with a stream subscription" do
    question = Question.create!(text: "hnsw?")

    get question_path(question)

    expect(response.body).to include("turbo-cable-stream-source", "Ищу источники")
  end

  it "renders citations as links and unknown ones in red" do
    chunk = create(:chunk, section_ref: "pgvector > HNSW")
    question = Question.create!(text: "hnsw?", status: "answered", answer: "Graph <b>index</b> [S1], invented [S7].",
                                chunk_ids: [ chunk.id ], citations: { "cited" => [ 1 ], "invalid" => [ 7 ] })

    get question_path(question)

    expect(response.body).to include('href="#source-S1"', 'id="source-S1"', "pgvector &gt; HNSW", "bg-red-100", "&lt;b&gt;index")
    expect(response.body).to include("несуществующие источники: S7")
  end

  it "shows not-found as a normal result and lists recent questions" do
    Question.create!(text: "weather in Minsk", status: "not_found", answer: RagAnswerer::NOT_FOUND)

    get questions_path
    expect(response.body).to include("weather in Minsk", "not_found")

    get question_path(Question.last)
    expect(response.body).to include("В источниках ответа нет")
  end
end
