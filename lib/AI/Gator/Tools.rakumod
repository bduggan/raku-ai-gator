unit module AI::Gator::Tools;
use Log::Async;

use AI::Gator::ToolBuilder;

sub get-tools is export {
 unless $*tool-dir.IO.d {
   warning "Could not find directory $*tool-dir";
   return [];
 }

 for $*tool-dir.dir -> $file {
   info "Loading tools from $file";
   my $code = $file.slurp;
   $code.EVAL;
 }

 my @names = (OUR::.keys).grep: { .Str ne 'EXPORT' }
 cache @names.map: {
    %( spec => build-tool( OUR::{$_} ), func => OUR::{$_} )
 }
}

sub lookup-tool(Str $name) is export {
  get-tools.first: {
    .<spec><function><name> eq $name
  }
}

sub get-tool-spec(Str $name) is export {
  lookup-tool($name)<spec>;
}

sub get-tool(Str $name) is export {
  lookup-tool($name)<func>;
} 