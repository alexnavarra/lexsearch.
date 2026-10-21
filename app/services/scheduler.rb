# SM-2 spaced repetition (as in Anki/SuperMemo), simplified. Pure: no DB, no clock of its own.
# A good answer pushes the next review further out; a score below 3 starts the card over.
class Scheduler
  State = Data.define(:ease, :interval_days, :repetitions)

  MIN_EASE = 1.3
  PASS_SCORE = 3

  def self.call(state, score) = new(state, score).call

  def initialize(state, score)
    raise ArgumentError, "score must be 0..5, got #{score.inspect}" unless (0..5).cover?(score)

    @state, @score = state, score
  end

  def call
    interval, repetitions =
      if @score < PASS_SCORE
        [ 1, 0 ]
      else
        [ next_interval, @state.repetitions + 1 ]
      end

    State.new(ease: next_ease, interval_days: interval, repetitions:)
  end

  private

  def next_interval
    case @state.repetitions
    when 0 then 1
    when 1 then 6
    else (@state.interval_days * @state.ease).round
    end
  end

  # 5 adds 0.1, 4 keeps it, 3 subtracts 0.14, 0 subtracts 0.8; rounded to dodge float noise
  def next_ease
    miss = 5 - @score
    [ (@state.ease + 0.1 - miss * (0.08 + miss * 0.02)).round(2), MIN_EASE ].max
  end
end
