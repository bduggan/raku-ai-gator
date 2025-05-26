use AI::Gator::Session;
use Log::Async;
use Terminal::ANSI::OO 't';
use HTTP::Tiny;
use JSON::Fast;

#| Base class, which is OpenAI-compatible.
class AI::Gator {

  has $.toolbox = Supplier.new;
  has $.ua = HTTP::Tiny.new;
  has Str $.model;
  has @.tools;
  has %.tool-funcs;
  has Supply $.tools-supply;
  has $.base-uri = 'https://api.openai.com/v1';

  submethod TWEAK {
    $!tools-supply = $!toolbox.Supply;
    for @!tools -> $tool {
      trace "tool :" ~ to-json $tool<spec>;
      my $name = $tool<spec><function><name>;
      my $func = $tool<func>;
      next unless defined $name;
      %!tool-funcs{$name} = $func;
    }
  }

  method post(Str $url!, Hash $content! --> Str) {
    debug "POST $url with content: " ~ to-json $content;
    my $res = $.ua.post: $url,
      :content(to-json $content),
      headers => { 'Content-Type' => 'application/json' };
    die "http error ({$res<status reason>}): " ~ ($res<content>.?decode // '') unless $res<success>;
    $res<content>.decode;
  }

  method post-stream(Str $url!, Hash $payload! --> Supply) {
    supply {
      my $errs is default('');
      my $content = to-json $payload;
      my %headers = 'Content-Type' => 'application/json';
      debug "POST (async) $url with content: " ~ $content;
      my $res = $.ua.post: $url, :$content, :%headers,
        data-callback => sub ( $blob, $state ) {
          trace "received data $state<status reason> bytes=" ~ $blob.elems ~ " data=" ~ $blob.decode;
          emit $blob;
          $errs ~= $blob.decode;
      }
      die "http error ({$res<status reason>}): $errs" unless $res<success>;
      done;
    }
  }

  method tool-builder($session) {
    my %call-me;
    # Arguments are sent in fragments of json, so we have to assemble them.
    react whenever self.tools-supply -> $tool {
      for $tool.list -> $t {
          if $t<id> && %call-me<id> && ($t<id> ne %call-me<id>) {
             debug "adding tool call " ~ to-json %call-me;
             $session.add-tool-call(%call-me.clone);
             %call-me<arguments> = "";
          }
          %call-me<index> = $_ with $t<index>;
          %call-me<id> = $_ with $t<id>;
          %call-me<name> = $_ with $t<function><name>;
          %call-me<arguments> ~= $_ with $t<function><arguments>;
      }
    }
    debug "adding tool call " ~ to-json %call-me if %call-me<id>;
    $session.add-tool-call(%call-me) if %call-me<id>;
  }

  method output($text) {
    print $text;
  }

  #| Display a streaming response and also emit tool calls as they come in.
  method get-response($session --> Str) {
    my $tool-promise = start self.tool-builder($session);
    my $response is default('');
    my $printed = 0;
    react whenever self.chat($session) -> $chunk {
      self.output(t.yellow ~ "Gator: " ~ t.text-reset) if $chunk.chars > 0 && !($printed++);
      self.output: $chunk;
      $response ~= $chunk;
    }
    put "" if $response.trim.chars && !$response.ends-with("\n");
    await $tool-promise;
    return $response.trim;
  }

  method summarize($session --> Str) {
    my $response;
    my @messages = $session.with-message: 'Make a very brief description of the conversation -- no more than 40 characters.';
    self.chat-once($session, :@messages);
  }

  method chat-once($session, :@messages = $session.messages --> Str) {
    return self.post("{ $.base-uri }/chat/completions",
      %( :$.model, :@messages, :tools(@.tools.map(*<spec>)) )
    ).&from-json<choices>[0]<message><content>;
  }

  method chat-stream($session, :@messages = $session.messages --> Supply) {
    return self.post-stream: "{ $.base-uri }/chat/completions",
      %( :stream, :$.model, :@messages, :tools(@.tools.map(*<spec>)) );
  }

  method process-byte-stream(Supply $byte-stream, $session --> Supply) {
    my $buffer;
    supply whenever $byte-stream.map(*.decode) {
      $buffer ~= $_;
      if $buffer.contains("\n") {
        $buffer.emit;
        $buffer = ''
      }
   }
  }

  method chat(AI::Gator::Session $session) {
      my $byte-stream = self.chat-stream($session);
      my $json-stream = self.process-byte-stream: $byte-stream, $session;

      supply whenever $json-stream.lines {
        done when /data \s* ':' \s* '[DONE]' /;

        when /data ':' (.*)/ {
          my $data = try from-json $0 or fail "failed to parse json: $0";
          given $data<choices>[0] {
            with .<finish_reason> {
               $session.last-finish-reason = $_;
               $.toolbox.done;
               done if $_ eq 'stop';
            }
            given .<delta> {
              .emit with .<content>;                 # text
              $.toolbox.emit: $_ with .<tool_calls>; # tool call
            }
          }
        }
      }
  }

  method add-tool-call-message($session,%call) {
    $session.add-message: :role<assistant>, tool_calls => [ {
      id => %call<id>, type => 'function',
      function => { name => %call<name>, arguments => %call<arguments> }
    },
   ];
  }

  method add-tool-response($session, :$tool_call_id, :$tool-response, :$name) {
    $session.add-message: :role<tool>, :$tool_call_id, :content($tool-response);
  }

  method do-tool-calls($session) {
    return unless $session.has-pending-tool-calls;
    debug "number of tool calls: " ~ $session.tool-calls.elems;
    for $session.tool-calls.list -> %call-me {
      debug "adding tool call " ~ %call-me.raku;
      my $arg-summary = %call-me<arguments>.Str;
      if $arg-summary.chars > 40 {
        $arg-summary = %call-me<arguments>.Str.substr(0, 40) ~ '...';
      }
      self.output: t.cyan ~ "[tool]" ~ t.text-reset ~ ' ' ~ %call-me<name> ~ t.color('#8888ff') ~ ' ' ~ $arg-summary;
      self.add-tool-call-message($session,%call-me);

      my $args = %call-me<arguments>;
      $args = (try from-json( $args ) ) if $args ~~ Str;

      die "failed to parse tool call arguments: { %call-me<arguments>.raku }" without $args;

      my $callback = self.tool-funcs{ %call-me<name> };
      my $tool-response = try $callback(|$args).Str;
      if $! {
        $tool-response = "Error: {$!}";
        warning "tool call failed: {$!}";
      }
      debug "tool response: $tool-response";
      self.add-tool-response: $session, tool_call_id => %call-me<id>, :$tool-response, name => %call-me<name>;
      self.output: t.cyan ~ "\n[tool]" ~ t.text-reset ~ ' ' ~ %call-me<name> ~ ' done' ~ "\n"
    }
    $session.clear-tool-calls;
    debug "done with tool calls";
  }
}

class AI::Gator::Gemini is AI::Gator {

  has $.base-uri = 'https://generativelanguage.googleapis.com/v1beta/models';
  has $.key = %*ENV<GEMINI_API_KEY>;

  method chat-once($session, :@messages = $session.messages --> Str) {
    return self.post: "{ $.base-uri }/{ $.model }:generateContent?key={ $.key }", %(
      :contents(@messages),
      |(@.tools ?? { tools => [ { functionDeclarations => @.tools.map(*<spec><function>) } ] } !! {})
    );
  }

  method chat-stream($session, :@messages = $session.messages --> Supply) {
    return self.post-stream: "{ $.base-uri }/{ $.model }:streamGenerateContent?key={ $.key }", %(
      :contents(@messages),
      |(@.tools ?? { tools => [ { functionDeclarations => @.tools.map(*<spec><function>) } ] } !! {})
    )
  }

   method chat(AI::Gator::Session $session) {
     my $byte-stream = self.chat-stream($session);
     supply whenever $byte-stream.map(*.decode) -> $data {
        my $json-data = (try from-json $data)
          // (try from-json $data ~ ']')
          // (try from-json $data.subst( /^^ [',' | ']'] $$/ ,''));
       if $json-data ~~ List {
           $json-data = $json-data[0]
       }

       unless $json-data ~~ Hash && $json-data<candidates> {
         error "data was $data " ~ $json-data.raku;
         die "data was not a valid Gemini response";
       }
       for $json-data<candidates>.list -> $candidate {
         given $candidate {
           with .<content><parts> {
             for .list -> $part {
               trace "gemini response part: " ~ to-json $part;
               .emit with $part<text>;

               with $part<functionCall> {
                 $.toolbox.emit: $_
               }
             }
           }

           with .<finishReason> {
             $session.last-finish-reason = $_ eq 'TOOL_CALLS' ?? 'tool_calls' !! $_;
             $.toolbox.done if $_ eq 'STOP';
             done if $_ eq 'STOP';
           }
         }
       }
     }
   }

   method tool-builder($session) {
    react whenever self.tools-supply -> $tool {
      debug "building gemini tool :" ~ to-json $tool;
      $session.add-tool-call(%( name => $tool<name>, arguments => $tool<args> ));
    }
  }

  method add-tool-call-message($session,%call) {
    $session.add-message: :role<model>, parts => [ {
     functionCall => { name => %call<name>, args => %call<args> } }, ];
  }

  method add-tool-response($session, :$tool_call_id, :$tool-response, :$name) {
    $session.add-message: :role<function>, parts => [ {
          functionResponse => { :$name, response => { content => $tool-response } }
     }, ];
  }
} 
