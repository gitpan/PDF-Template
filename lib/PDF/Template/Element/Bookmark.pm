package PDF::Template::Element::Bookmark;

use strict;

BEGIN {
    use vars qw(@ISA);
    @ISA = qw(PDF::Template::Element);

    use PDF::Template::Element;
}

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->{TXTOBJ} = PDF::Template::Factory->create('TEXTOBJECT');

    return $self;
}

sub render
{
    my $self = shift;
    my ($context) = @_;

    return 0 unless $self->should_render($context);

    return 1 if $context->{CALC_LAST_PAGE};

    my $txt = $self->{TXTOBJ}->resolve($context);

    unless (defined $txt)
    {
        warn "Bookmark: no text defined!", $/;
        $txt = 'undefined';
    }

    pdflib_pl::PDF_add_bookmark($context->{PDF}, $txt, 0, 0);

    return 1;
}

1;
__END__

=head1 NAME

PDF::Template::Element::Bookmark

=head1 PURPOSE

Creates a bookmark in the resultant PDF.

=head1 NODE NAME

&lt;bookmark&gt;

=head1 INHERITANCE

PDF::Template::Element

=head1 ATTRIBUTES

None

=head1 CHILDREN

Text and &lt;VAR&gt; nodes. The text contained will be the location of the
bookmark.

=head1 AFFECTS

Resultant PDF

=head1 DEPENDENCIES

None

=head1 USAGE

Add it anywhere you would like a bookmark to appear in the PDF.

=head1 AUTHOR

Rob Kinyon (rkinyon@columbus.rr.com)

=head1 SEE ALSO

TBA

=cut
