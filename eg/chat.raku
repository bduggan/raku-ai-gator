use AI::Gator;

my AI::Gator $gator = AI::Gator::Gemini.new: model => 'gemini-2.0-flash';
my AI::Gator::Session $session = AI::Gator::Session::Gemini.new;

$session.add-message: "Hello, Gator!";

react whenever $gator.chat($session) -> $chunk {
  print $chunk;
}

# Hello! How can I help you today?

