use AI::Gator;

my AI::Gator $gator = AI::Gator::Gemini.new: model => 'gemini-2.0-flash';
my AI::Gator::Session $session = AI::Gator::Session::Gemini.new;

$session.add-message: "Hello, Gator!";

react whenever $gator.chat($session) { .print }

# Hello! How can I help you today?

$session.add-message: "What is the capital of France?";

react whenever $gator.chat($session) { .print }

# The capital of France is Paris.

$session.add-message: "What is its population?";

react whenever $gator.chat($session) { .print }
