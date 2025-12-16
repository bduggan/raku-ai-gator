#!raku

use Log::Async;
use JSON::Fast;

class AI::Gator::Session {
  has @.messages;
  has @.tool-calls;
  has $.last-finish-reason is rw is default('');
  has IO::Path $.session-dir;
  has IO::Path $.session-file;

  method TWEAK {
    with $!session-dir {
      .d or mkdir $_;
    } else {
      unless $!session-file {
        my $default = $*HOME.child('ai-gator').child('sessions');
        debug "writing sessions to $default";
        $!session-dir = $default;
      }
    }
    $!session-file //= $!session-dir.child(now.Rat ~ '.json');
  }
  multi method add-message($content, :$role = 'user', *%args) {
    @!messages.push: { :$role, :$content, |%args };
  }
  multi method add-message(:$role = 'user', *%args) {
    @!messages.push: { :$role, |%args };
  }
  method add-tool-call(%args) {
    @!tool-calls.push: %args.deepmap: { $_ }
  }
  method clear-tool-calls {
    @!tool-calls := [];
  }
  method has-pending-tool-calls {
    return @!tool-calls.elems > 0;
  }
  method save(:$summary) {
    info "saving session to {$!session-file}";
    info "summary: {$summary}" if $summary;
    $!session-file.spurt: to-json %( :@!messages, :$summary, timestamp => DateTime.now.Str );
  }
  multi method with-message($content, :$role = 'user', *%args) {
    my @messages = @.messages;
    @messages.push: { :$role, :$content };
    @messages;
  }

  multi method load(IO::Path $file) {
    info "loading session from {$file}";
    my $data = from-json $file.slurp;
    @!messages := $data<messages>;
    $.last-finish-reason = $data<last_finish_reason> // '';
    $!session-file = $file;
    info "loaded session with { @!messages.elems } messages";
    return True;
  }

  method load-last-session(IO::Path $dir) {
    my @files = $dir.dir(test => *.ends-with('.json'));
    return unless @files;
    return self.load: @files.sort({ .modified }).tail
  }

  method list-sessions(IO::Path $dir) {
    my @files = $dir.dir(test => *.ends-with('.json'));
    return unless @files;
    @files.sort({ .modified }).map: {
      my %h = from-json .slurp;
      %h<filename> = ~$_;
      %h;
    }
  }
}

class AI::Gator::Session::Gemini is AI::Gator::Session {
  multi method add-message($content, :$role = 'user', *%args) {
    @.messages.push: { :$role, parts => [ { text => $content }, ], |%args };
  }
  multi method with-message($content, :$role = 'user', *%args) {
    my @messages = @.messages;
    @messages.push: { :$role, parts => [ { text => $content }, ], |%args };
    @messages;
  }
}

class AI::Gator::Session::OpenRouter is AI::Gator::Session {
  # OpenRouter is OpenAI-compatible, so no custom methods needed
}
