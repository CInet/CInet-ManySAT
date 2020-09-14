=encoding utf8

=head1 NAME

CInet::ManySAT::All - Talk to an asynchronous AllSAT solver

=head1 SYNOPSIS

    my $all = $solver->all;
    while (defined(my $model = $all->next)) {
        say $model;
        $all->cancel and last if had_enough;
    }

    # Or read them all at once into memory:
    say for $all->list;

=cut

# ABSTRACT: Talk to an asynchronous AllSAT solver
package CInet::ManySAT::All;

use Modern::Perl 2018;

=head1 DESCRIPTION

This class encapsulates an AllSAT solver process that is running
asynchronously and producing models. It is returned by the C<all>
method of L<CInet::ManySAT> to allow you to manage the enumeration,
including canceling it when you lose interest.

When this object is destroyed, it automatically calls L<cancel>.

=head2 Methods

=head3 new

    my $all = CInet::ManySAT::All->new($pid, $fh);

Create a new instance managing an C<nbc_minisat_all> process from
via a process ID and a filehandle for its standard output.

If you must use this constructor directly, use the C<nbc_minisat_all>
executable from L<CInet::Alien::MiniSAT::All>. In this case, you want
to redirect its standard error to C</dev/null>.

=cut

sub new {
    my ($class, $pid, $fh) = @_;
    bless { pid => $pid, fh => $fh }, $class
}

=head3 next

    my $model = $all->next;

Returns the next model provided by the solver as an arrayref of literals.
This method may block until sufficient data is available. If the process
finished (or was canceled), C<undef> is returned.

=cut

sub next {
    my $self = shift;
    return undef if $self->{pid} == 0 or eof($self->{fh});
    my $line = readline($self->{fh});
    [ grep { $_ } $line =~ m/(-?\d+)/g ]
}

=head3 cancel

    $model->cancel;

Signal the enumeration process to terminate, wait for it to comply and
free other resources associated with the process.

=cut

sub cancel {
    my $self = shift;
    return if $self->{pid} == 0;
    kill 'TERM', $self->{pid};
    $self->_finish;
}

=head3 list

    my @models = $all->list;

Eagerly obtain all (remaining) models and return them as a list. Use this
method with caution as it may eat huge amounts of memory.

=cut

sub list {
    my $self = shift;

    my @list;
    while (defined(my $model = $self->next)) {
        push @list, $model;
    }
    $self->_finish;

    @list
}

sub _finish {
    my $self = shift;
    return if $self->{pid} == 0;
    waitpid $self->{pid}, 0;
    $self->{pid} = 0;
    close $self->{fh};
}

sub DESTROY {
    my $self = shift;
    $self->cancel;
}

=head1 AUTHOR

Tobias Boege <tobs@taboege.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (C) 2020 by Tobias Boege.

This is free software; you can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

=cut

":wq"
