package PDF::Template::Element;

use strict;

BEGIN {
    use vars qw(@ISA);
    @ISA = qw(PDF::Template::Base);

    use PDF::Template::Base;
}

sub set_color
{
    my $self = shift;
    my ($context, $attr, $mode, $depth) = @_;

    my $color = $context->get($self, $attr, $depth);

    return 1 unless $color;

    my @colors = map { $_ / 255 } split /,\s*/, $color, 3;

    if ($context->{PDF_VERSION} >= 4)
    {
        pdflib_pl::PDF_setcolor($context->{PDF}, $mode, 'rgb', @colors, 0);
    }
    else
    {
        if ($mode eq 'fill')
        {
            pdflib_pl::PDF_setrgbcolor_fill($context->{PDF}, @colors);
        }
        elsif ($mode eq 'stroke')
        {
            pdflib_pl::PDF_setrgbcolor_stroke($context->{PDF}, @colors);
        }
        else # ($mode eq 'both')
        {
            pdflib_pl::PDF_setrgbcolor($context->{PDF}, @colors);
        }
    }

    return 1;
}

1;
__END__

=head1 NAME

PDF::Template::Element

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
