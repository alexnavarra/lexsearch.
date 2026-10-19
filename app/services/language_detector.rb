# Picks the text search config by the share of Cyrillic letters.
# Crude on purpose: our sources are either Russian or English, code and terms are Latin anyway.
class LanguageDetector
  RUSSIAN_SHARE = 0.3

  def self.call(text)
    letters = text.to_s.scan(/\p{L}/)
    return "english" if letters.empty?

    cyrillic = letters.count { _1.match?(/\p{Cyrillic}/) }
    cyrillic.fdiv(letters.size) >= RUSSIAN_SHARE ? "russian" : "english"
  end
end
