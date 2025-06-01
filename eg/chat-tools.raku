use Log::Async;
use AI::Gator;
use AI::Gator::ToolBuilder;

#| Get real time weather for a given city
sub get_weather(
   Str :$city! #= The city to get the weather for
) {
   "The weather in $city is sunny.";
}

my $spec = build-tool(&get_weather);
my AI::Gator $gator = AI::Gator::Gemini.new: model => 'gemini-2.0-flash',
  tools => [
    { spec => $spec, func => &get_weather },
  ];

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
say $session.last-finish-reason;

