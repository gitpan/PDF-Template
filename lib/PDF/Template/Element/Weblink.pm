package PDF::Template::Element::Weblink;

use strict;

BEGIN {
    use vars qw(@ISA);
    @ISA = qw(PDF::Template::Element);

    use PDF::Template::Element;
}

sub render
{
    my $self = shift;
    my ($context) = @_;

    return 0 unless $self->should_render($context);

    return 1 if $context->{CALC_LAST_PAGE};

    my $url = $context->get($self, 'URL');

    unless (defined $url)
    {
        warn "Weblink: no text defined!", $/;
        return 1;
    }

    pdflib_pl::PDF_add_weblink(
        $context->{PDF},
        $self->{X1}, $self->{Y1},
        $self->{X2}, $self->{Y2},
        $url,
    );

    return 1;
}

1;
__END__

=head1 NAME

PDF::Template::Element::WebLink

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
