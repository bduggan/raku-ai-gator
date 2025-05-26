unit module AI::Gator::ToolBuilder;

sub build-tool(&func) is export {
  my $sig = &func.signature;
  my %properties;
  my @required;
  for $sig.params.list -> $param {
    my $name = $param.name.subst('$', '');
    my $description = $param.WHY || die "No description found for parameter $name ($sig)";
    %properties{$name} = {
      type => $param.does(Numeric) ?? 'number' !! 'string',
      description => ~$param.WHY
    };
    @required.push($name) if ($param.suffix // '') eq '!';
  }

  my $description = &func.WHY;
  without $description {
    note "Missing description for { &func.name } in { &func.file } lines { &func.line }";
    exit;
  }

  return {
    type => 'function',
    function => {
       name => &func.name,
       description => ~( &func.WHY or die "No description found for { &func.name }" ),
       parameters => {
         type => 'object',
         properties => %properties,
         required => @required
       }
    }
  }
} 
