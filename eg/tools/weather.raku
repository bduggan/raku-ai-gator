#| Get real time weather for a given city
our sub get_weather(
   Str :$city! #= The city to get the weather for
) {
   "The weather in $city is sunny.";
}
