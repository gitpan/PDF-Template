package PDF::Template::Element::HorizontalRule;

use strict;

BEGIN {
    use vars qw(@ISA);
    @ISA = qw(PDF::Template::Element::Line);

    use PDF::Template::Element::Line;
}

sub deltas
{
    my $self = shift;
    my ($context) = @_;

    my $y_shift = $self->{Y2} - $self->{Y1};
    $y_shift = -1 * ($context->get($self, 'H') || 0) unless $y_shift;

    return {
        Y => $y_shift,
    };
}

1;
__END__

=head1 NAME

PDF::Template::Element::HorizontalRule

=head1 PURPOSE

=head1 NODE NAME

=head1 INHERITANCE

=head1 ATTRIBUTES

=head1 CHILDREN

=head1 AFFECTS

=head1 DEPENDENCIES

=head1 USAGE

=head1 AUTHOR

Rob Kinyon (rkinyon@columbus.rr.com)

=head1 SEE ALSO

=cut
