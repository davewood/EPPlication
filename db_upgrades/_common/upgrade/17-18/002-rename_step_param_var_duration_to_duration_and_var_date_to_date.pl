#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

# schema upgrade v17-v18
# changes the step parameter key 'var_date' to 'date'
# changes the step parameter key 'var_duration' to 'duration'

use
    DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::ScriptHelpers
    'schema_from_schema_loader';

schema_from_schema_loader(
    { naming => { ALL => 'v8', force_ascii => 1 } },
    sub {
        my ( $schema, $versions ) = @_;

        my $steps_rs = $schema->resultset('Step');

        say "Rename parameters->{var_date} to parameters->{date}"
          . " and add TT start/end tag around old var_date value\n"
          . "Rename parameters->{var_duration} to parameters->{duration}"
          . " and add TT start/end tag around old var_duration value\n";

        while ( my $step = $steps_rs->next ) {
            if ($step->type eq 'DateAdd') {

                say "Updating step " . $step->id;

                # because DBIDH does not inflate $step->parameters to JSON
                # we do it manually with raw column data as source

                my $params_raw = $step->get_column('parameters');

                use JSON qw/ encode_json decode_json /;
                my $params = decode_json($params_raw);

                say "\told: ";
                use Data::Dumper;
                say "\t" . Dumper($params);

                my $params_date = delete $params->{var_date};
                $params->{date} = '[% ' . $params_date . ' %]';
                my $params_duration = delete $params->{var_duration};
                $params->{duration} = '[% ' . $params_duration . ' %]';
                $step->set_column('parameters' => encode_json($params));
                $step->update();

                say "\tnew:";
                say "\t" . Dumper($params);
            }
        }
    }
);
