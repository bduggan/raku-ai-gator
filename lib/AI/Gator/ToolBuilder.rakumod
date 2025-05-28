unit module AI::Gator::ToolBuilder;
use Log::Async;

sub build-tool(&func) is export {
  my $sig = &func.signature;
  my %properties;
  my @required;
  my $where = 'function ' ~ &func.name ~ ' on line ' ~ &func.line;
  debug "loading function $where";
  for $sig.params.list -> $param {
    my $name = $param.name.subst('$', '');
    my $description = $param.WHY.Str.?trim || die "No description found for parameter $name ($where)";
    %properties{$name} = {
      type => $param.does(Numeric) ?? 'number' !! 'string',
      description => ~$param.WHY
    };
    @required.push($name) if ($param.suffix // '') eq '!';
  }

  my $description = &func.WHY.Str.trim;
  without $description {
    note "Missing description for { &func.name } at line { &func.line }";
    exit;
  }

  return {
    type => 'function',
    function => {
       name => &func.name,
       :$description,
       parameters => {
         type => 'object',
         properties => %properties,
         required => @required
       }
    }
  }
} 
