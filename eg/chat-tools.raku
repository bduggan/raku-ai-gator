use Log::Async;
use AI::Gator;

#| Get real time weather for a given city
sub get_weather(
   Str :$city! #= The city to get the weather for
) {
   "The weather in $city is sunny.";
}

my AI::Gator $gator = AI::Gator::Gemini.new:
  model => 'gemini-2.0-flash',
  :quiet,
  tools => @( &get_weather, );

my AI::Gator::Session $session = AI::Gator::Session::Gemini.new;

$session.add-message: "Hello ailigator!";
react whenever $gator.chat($session) { .print }
# Hello! How can I help you today? 🐊

my $tool-promise = start $gator.tool-builder($session);
$session.add-message: "What is the weather in Paris?";
react whenever $gator.chat($session) { .print }
await $tool-promise;

$gator.do-tool-calls: $session;

react whenever $gator.chat($session) { .print }
# The weather in Paris is sunny.

