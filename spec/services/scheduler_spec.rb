require "rails_helper"

RSpec.describe Scheduler do
  def state(ease: 2.5, interval: 0, reps: 0) = Scheduler::State.new(ease:, interval_days: interval, repetitions: reps)

  # [before, score] => [ease, interval_days, repetitions]
  {
    "new card, perfect" => [ { reps: 0 }, 5, [ 2.6, 1, 1 ] ],
    "new card, good" => [ { reps: 0 }, 4, [ 2.5, 1, 1 ] ],
    "new card, barely" => [ { reps: 0 }, 3, [ 2.36, 1, 1 ] ],
    "second success" => [ { interval: 1, reps: 1 }, 4, [ 2.5, 6, 2 ] ],
    "third success multiplies by ease" => [ { interval: 6, reps: 2 }, 4, [ 2.5, 15, 3 ] ],
    "uses the old ease, not the new one" => [ { ease: 2.0, interval: 10, reps: 3 }, 5, [ 2.1, 20, 4 ] ],
    "failure starts over" => [ { interval: 15, reps: 3 }, 2, [ 2.18, 1, 0 ] ],
    "zero drops ease the most" => [ { interval: 15, reps: 3 }, 0, [ 1.7, 1, 0 ] ],
    "ease never goes below 1.3" => [ { ease: 1.4, interval: 3, reps: 2 }, 0, [ 1.3, 1, 0 ] ],
    "low ease still grows the interval" => [ { ease: 1.3, interval: 3, reps: 2 }, 3, [ 1.3, 4, 3 ] ]
  }.each do |name, (before, score, (ease, interval, reps))|
    it name do
      expect(described_class.call(state(**before), score))
        .to eq(Scheduler::State.new(ease:, interval_days: interval, repetitions: reps))
    end
  end

  it "rejects scores outside 0..5" do
    expect { described_class.call(state, 6) }.to raise_error(ArgumentError)
    expect { described_class.call(state, nil) }.to raise_error(ArgumentError)
  end
end
