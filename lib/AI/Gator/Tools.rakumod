unit module AI::Gator::Tools;
use Log::Async;

use AI::Gator::ToolBuilder;

our @TOOLS;

sub get-tools is export {
 unless $*tool-dir.IO.d {
   info "Making directory $*tool-dir";
   mkdir $*tool-dir;
   return [];
 }

 return @TOOLS if @TOOLS.elems > 0;

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

 my @names = (OUR::.keys).grep: { .Str ne 'EXPORT' | '@TOOLS' }
 @TOOLS = @names.sort.map: {
    %( spec => build-tool( OUR::{$_} ), func => OUR::{$_} )
 }
 return @TOOLS;
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
