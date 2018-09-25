#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use JSON;

# add default ssh port to SSH steps

use
  DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::ScriptHelpers
  'schema_from_schema_loader';

schema_from_schema_loader(
    { naming => { ALL => 'v8', force_ascii => 1 } },
    sub {
        my ( $schema, $versions ) = @_;

        my $step_rs;

        $step_rs = $schema->resultset('Step')->search({ type => 'SSH' });
        while ( my $step = $step_rs->next ) {
            say 'Add default SSH port 22 to step ' . $step->id;
            add_param($step);
        }
    }
);

sub add_param {
    my ($step) = @_;

    my $params_raw = $step->get_column('parameters');
    my $params = from_json($params_raw);

    $params->{ssh_port} = '[% ssh_port %]';

    $step->set_column( 'parameters' => to_json($params) );
    $step->update();
}
