[![Actions Status](https://github.com/bduggan/raku-ai-gator/actions/workflows/linux.yml/badge.svg)](https://github.com/bduggan/raku-ai-gator/actions/workflows/linux.yml)
[![Actions Status](https://github.com/bduggan/raku-ai-gator/actions/workflows/macos.yml/badge.svg)](https://github.com/bduggan/raku-ai-gator/actions/workflows/macos.yml)

NAME
====

AI::Gator - Ailigator -- your AI Generic Assistant with a Tool-Oriented REPL

<img src="https://github.com/user-attachments/assets/0e71fb98-e149-483a-8654-300316e413e8" alt="ailigator" width="300">

SYNOPSIS
========

Put this into $HOME/ai-gator/tools/weather.raku:

    #| Get real time weather for a given city
    our sub get_weather(
       Str :$city! #= The city to get the weather for
    ) {
       "The weather in $city is sunny.";
    }

Then start the AI Gator REPL:

    $ ai-gator

    You: Is it raining in Toledo?
    [tool] get_weather city Toledo
    [tool] get_weather done
    Gator: No, it is not raining in Toledo. The weather is sunny.
    You: What about Philadelphia or San Francisco?
    [tool] get_weather city Philadelphia
    [tool] get_weather done
    [tool] get_weather city San Francisco
    [tool] get_weather done
    Gator: It is sunny in both Philadelphia and San Francisco.

For other options, run:

    $ ai-gator -h

This module can also be used programmatically:

    use AI::Gator;

    my AI::Gator $gator = AI::Gator::Gemini.new: model => 'gemini-2.0-flash';
    my AI::Gator::Session $session = AI::Gator::Session::Gemini.new;

    $session.add-message: "Hello, Gator!";

    react whenever $gator.chat($session) -> $chunk {
      print $chunk;
    }

    # Hello! How can I help you today?

DESCRIPTION
===========

AI::Gator is an AI assistant oriented towards using tools and a REPL interface.

Features:

- streaming responses

- tool definitions in Raku

- tool calls

- session storage

- Gemini and OpenAI support

- REPL interface with history

Tools are defined as Raku functions and converted into an OpenAI or Gemini specification using declarator pod and other native Raku features.

All sessions are stored in the sessions/ directory, and the REPL stores the history in a .history file, readline-style.

CONFIGURATION
=============

Set AI_GATOR_HOME to ai-gator's home (by default $HOME/ai-gator).

In this directory, the following files and directories are used:

- config.toml: configuration file

- tools/: directory with files containing tools

- sessions/: directory with session files (created by the REPL)

- .history: file with readline history (also created by the REPL)

CONFIGURATION FILE
==================

Sample configuration to use Gemini:

    model = "gemini-2.0-flash"
    adapter = 'Gemini'

Sample configuration to use OpenAI:

    model = "gpt-4o"
    base-uri = "https://api.openai.com/v1"

ENVIRONMENT
===========

- AI_GATOR_HOME: home directory for AI::Gator (default: $HOME/ai-gator)

- GEMINI_API_KEY: API key for Gemini (if using Gemini)

- OPENAI_API_KEY: API key for OpenAI (if using OpenAI)

NOTES
=====

This is all pretty rough and experimental. Expect the api to change. Patches welcome!

AUTHOR
======

Brian Duggan

