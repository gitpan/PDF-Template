package PDF::Template::Element::Line;

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

    my $p = $context->{PDF};

    pdflib_pl::PDF_save($p);

    $self->set_color($context, 'COLOR', 'both');

    my $vals = $self->make_vals($context);

    my $width = $context->get($self, 'WIDTH') || 1;

    pdflib_pl::PDF_setlinewidth($p, $width);
    pdflib_pl::PDF_moveto($p, $vals->{X1}, $vals->{Y1});
    pdflib_pl::PDF_lineto($p, $vals->{X2}, $vals->{Y2});
    pdflib_pl::PDF_stroke($p);

    pdflib_pl::PDF_restore($p);

    return 1;
}

sub make_vals
{
    my $self = shift;
    my ($context) = @_;

    my ($x1, $x2, $y1, $y2) = map { $context->get($self, $_) } qw(X1 X2 Y1 Y2);

    my %vals;
    unless (defined $x1 && defined $x2)
    {
#GGG Is the use of W a bug here?
        my ($pw, $left, $right, $w) = map { $context->get($self, $_) } qw(PAGE_WIDTH LEFT_MARGIN RIGHT_MARGIN W);
        $w = $pw - $right - $left unless defined $w;

        if (defined $x1)
        {
            $x2 = $x1 + $w;
            $x2 = $right if $x2 > $right;
        }
        elsif (defined $x2)
        {
            $x1 = $x2 - $w;
            $x1 = $left if $x1 < $left;
        }
        else
        {
            $x1 = $left;
            $x2 = $x1 + $w;
        }
    }
    @vals{qw(X1 X2)} = ($x1, $x2);

    unless (defined $y1 && defined $y2)
    {
        my $y = $context->get($self, 'Y');
        if (defined $y1)
        {
            $y2 = $y1;
        }
        elsif (defined $y2)
        {
            $y1 = $y2;
        }
        else
        {
            $y1 = $y2 = $y;
        }
    }
    @vals{qw(Y1 Y2)} = ($y1, $y2);

    $self->{VALS} = \%vals;

    return \%vals;
}

1;
__END__

=head1 NAME

PDF::Template::Element::Line

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
