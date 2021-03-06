package EPPlication::Web::Role::Form::Step::Operator;
use HTML::FormHandler::Moose::Role;
use namespace::autoclean;

has_field 'operator' => (
    type         => 'Select',
    empty_select => 'Select ...',
    required     => 1,
    noupdate     => 1,
    options      => [ map { { value => $_, label => $_ } } qw{ + - * / && || } ],
);

around '_build_parameter_fields' => sub {
    my ($orig, $self) = @_;
    return [ @{ $self->$orig }, 'operator' ];
};

1;
