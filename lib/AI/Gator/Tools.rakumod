unit module AI::Gator::Tools;
use Log::Async;

use AI::Gator::ToolBuilder;

multi get-tools(:$funcs) is export {
  my @tools;
  for $funcs.list -> $func {
    my $spec = build-tool($func);
    @tools.push: { spec => $spec, func => $func };
  }
  return @tools;
}

multi get-tools is export {
 unless $*tool-dir.IO.d {
   warning "Could not find directory $*tool-dir";
   return [];
 }

 for $*tool-dir.dir(test => { .ends-with('.raku') }) -> $file {
   info "Loading tools from $file";
   my $code = $file.slurp;
   try $code.EVAL;
   if $! {
     error "Failed to load tools from $file: $!";
     next;
   }
   debug "successfully processed $file";
 }

 my @names = (OUR::.keys).grep: { .Str ne 'EXPORT' }
 cache @names.sort.map: {
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
