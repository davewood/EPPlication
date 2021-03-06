package EPPlication::CLI;
use Moose;
use namespace::autoclean;
use HTTP::CookieJar;
use JSON::PP;
use URI;
use URI::QueryParam;
extends 'EPPlication::HTTP::UA';

=head1 NAME

EPPlication::CLI - HTTP Command Line Interface for EPPlication

=head1 DESCRIPTION

A simple client to communicate with an EPPlication instance
to start and inspect jobs.

=head1 METHODS

=head2 new( host => $host, port => $port [, timeout => $seconds ])

inherited from EPPlication::HTTP::UA

=cut

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my %args = @_;
    my $timeout = delete $args{timeout};

    return $class->$orig(
        ua_options => [
            ( defined $timeout ? ( timeout => $timeout ) : () ),
            cookie_jar      => HTTP::CookieJar->new,
            default_headers => {
                'Accept'       => 'application/json',
                'Content-Type' => 'application/json; charset=utf-8',
            },
        ],
        @_
    );
};

=head2 login($username, $password)

returns 1 on success or 0 on error.

=cut

sub login {
    my ( $self, $username, $password ) = @_;

    my $content_raw = encode_json({ name => $username, password => $password });

    my $res = $self->ua->post(
        $self->api_base . '/login',
        { content => $content_raw },
    );

    my $status = $res->{status};

    # login successful
    if ( $status == 200 ) {
        return 1;
    }
    # login failed
    elsif ( $status == 400 ) {
        return 0;
    }
    # unknown error
    else {
        die "Unknown Status ($status)";
    }
}

=head2 logout

returns 1 on success or 0 on error.

=cut

sub logout {
    my ( $self ) = @_;

    my $res = $self->ua->post(
        $self->api_base . '/logout',
    );
    return $res->{status} eq '200'
      ? 1
      : 0;
}

=head2 $job_id = create_job(\%params)

The key I<test_id> is mandatory while the key I<config_id>
is optional in the I<%params> hashref.
On success the I<id> of the created job is returned.
An error will be thrown if an error occurrs.

=cut

sub create_job {
    my ( $self, $params ) = @_;

    $params->{job_type} = 'test';
    my $content_raw = encode_json($params);

    my $res = $self->ua->post(
        $self->api_base . '/job',
        { content => $content_raw },
    );

    my $status = $res->{status};
    # job created
    if ( $status == 201 ) {
        my $content_raw = $res->{content};
        my $content     = decode_json($content_raw);
        return $content->{job_id};
    }
    # error caught on server side
    elsif ( $status == 400 or $status == 403 ) {
        my $content_raw = $res->{content};
        my $content     = decode_json($content_raw);
        die $content->{error} . "\n";
    }
    # unknown error
    else {
        die "Unknown Status ($status)";
    }
}

=head2 get_job($job_id)

Returns the job details on success. I<$job-E<gt>{status}> can be
one of the values 'pending'|'in_progress'|'finished'|'error'.
If the job is finished I<$job-E<gt>{summary}> contains a hashref
with the keys I<num_steps> and I<errors>.
If no I<job> exists for the provided id I<undef> is returned.
In case of an error an exception is thrown.

    my $job = {
        status => 'finished',
        summary => {
            ok       => 7,
            errors   => 9,
        },
    };

=cut

sub get_job {
    my ( $self, $job_id ) = @_;

    my $uri = URI->new(
        $self->api_base . "/job/$job_id",
        'http',
    );

    my $res = $self->ua->get($uri);

    my $status = $res->{status};
    # job found
    if ( $status == 200 ) {
        my $content_raw = $res->{content};
        my $content     = decode_json($content_raw);
        return $content;
    }
    # no job found
    elsif ( $status == 404 ) {
        return;
    }
    # error caught on server side
    elsif ( $status == 400 or $status == 403 ) {
        my $content_raw = $res->{content};
        my $content     = decode_json($content_raw);
        die $content->{error} . "\n";
    }
    # unknown error
    else {
        die "Unknown Status ($status)";
    }
}

=head2 export_job($job_id)

Trigger export of job and return file location on success.
In case of an error an exception is thrown.

=cut

sub export_job {
    my ( $self, $job_id ) = @_;

    my $content_raw = encode_json({ job_id => $job_id });
    my $res = $self->ua->post(
        $self->api_base . '/job/export',
        { content => $content_raw },
    );

    my $status = $res->{status};
    # job has been exported
    if ( $status == 201 ) {
        return $res->{headers}{location};
    }
    # no job found
    elsif ( $status == 404 ) {
        return;
    }
    # error caught on server side
    elsif ( $status == 400 or $status == 403 ) {
        my $content_raw = $res->{content};
        my $content     = decode_json($content_raw);
        die $content->{error} . "\n";
    }
    # unknown error
    else {
        die "Unknown Status ($status)";
    }
}

=head2 download_job_report($location, $filename)

Download the exported job report.

=cut

sub download_job_report {
    my ( $self, $location, $filename ) = @_;
    die "$filename exists."
        if -x $filename;
    open( my $fh, '>', $filename )
      or die "Could not open file for writing. ($!)";
    my $res = $self->ua->get(
        $location,
        {
            data_callback => sub {
                my ($chunk, $res) = @_;
                print $fh $chunk;
            }
        },
    );

    my $status = $res->{status};
    # job has been exported
    if ( $status == 200 ) {
        if ($res->{url} =~ m/login/xms) {
            die 'Not logged in.';
        }
    }
    # error caught on server side
    elsif ( $status == 400 or $status == 403 ) {
        my $content_raw = $res->{content};
        my $content     = decode_json($content_raw);
        die $content->{error} . "\n";
    }
    # unknown error
    else {
        die "Unknown Status ($status)";
    }

}

=head2 get_branch_id_by_name($branch_name)

Return id associated with branch name.
Return 404 if not found.

=cut

sub get_branch_id_by_name {
    my ( $self, $branch_name ) = @_;

    my $uri = URI->new(
        $self->api_base . '/branch/lookup',
        'http',
    );
    $uri->query_param( name => $branch_name );

    my $res = $self->ua->get($uri);

    my $status = $res->{status};

    # test found
    if ( $status == 200 ) {
        my $content_raw = $res->{content};
        my $content     = decode_json($content_raw);
        return $content->{branch_id};
    }
    # no test found
    elsif ( $status == 404 ) {
        return;
    }
    # error caught on server side
    elsif ( $status == 400 or $status == 403 ) {
        my $content_raw = $res->{content};
        my $content     = decode_json($content_raw);
        die $content->{error} . "\n";
    }
    # unknown error
    else {
        die "Unknown Status ($status)";
    }
}

=head2 get_test_id_by_name($test_name, $branch_id)

Return id associated with test name and optional branch_id.
If branch_id is omitted, id of branch 'master" will be used.
Return 404 if not found.

=cut

sub get_test_id_by_name {
    my ( $self, $test_name, $branch_id ) = @_;

    my $uri = URI->new(
        $self->api_base . '/test/lookup',
        'http',
    );
    $uri->query_param( branch_id => $branch_id )
        if defined $branch_id;
    $uri->query_param( name      => $test_name );

    my $res = $self->ua->get($uri);

    my $status = $res->{status};
    # test found
    if ( $status == 200 ) {
        my $content_raw = $res->{content};
        my $content     = decode_json($content_raw);
        return $content->{test_id};
    }
    # no test found
    elsif ( $status == 404 ) {
        return;
    }
    # error caught on server side
    elsif ( $status == 400 or $status == 403 ) {
        my $content_raw = $res->{content};
        my $content     = decode_json($content_raw);
        die $content->{error} . "\n";
    }
    # unknown error
    else {
        die "Unknown Status ($status)";
    }
}

=head2 get_version()

Returns a hashref including the EPPlication and database schema version.

    {
        EPPlication => '0.8.20',
        database    => '48',
    };

=cut

sub get_version {
    my ( $self ) = @_;

    my $uri = URI->new(
        $self->api_base . '/version',
        'http',
    );

    my $res = $self->ua->get($uri);

    my $status = $res->{status};
    # job found
    if ( $status == 200 ) {
        my $content_raw = $res->{content};
        my $content     = decode_json($content_raw);
        return $content;
    }
    # error caught on server side
    elsif ( $status == 400 or $status == 403 ) {
        my $content_raw = $res->{content};
        my $content     = decode_json($content_raw);
        die $content->{error} . "\n";
    }
    # unknown error
    else {
        die "Unknown Status ($status)";
    }
}

__PACKAGE__->meta->make_immutable;
1;

=head1 AUTHOR

David Schmidt <david.schmidt@univie.ac.at>

=cut
