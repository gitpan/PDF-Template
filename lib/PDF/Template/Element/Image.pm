package PDF::Template::Element::Image;

use strict;

BEGIN {
    use vars qw(@ISA);
    @ISA = qw(PDF::Template::Element);

    use PDF::Template::Element;
}

sub new_unused
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

#GGG Currently unused
#    for (qw/ALIGN VALIGN/)
#    {
#        $self->{$_} = uc $self->{$_} if defined $self->{$_};
#    }

    return $self;
}

my %convertImageType = (
    'jpg' => 'jpeg',
);

sub begin_page
{
    my $self = shift;
    my ($context) = @_;

    return 1 if $context->{CALC_LAST_PAGE};

    my $txt = $context->get($self, 'FILENAME') ||
        $self->{TXTOBJ}->resolve($context) ||
        die "Image does not have a filename", $/;

    unless ($context->retrieve_image($txt))
    {
        # automatically resolve type if extension is obvious and type was not specified
        my $type = $context->get($self, 'TYPE');
        unless ($type)
        {
            ($type) = $txt =~ /\.(\w+)$/o;
        }
        unless ($type)
        {
            die "Undefined type for <image> '$txt'", $/;
        }

        $type = lc $type;
        $type = $convertImageType{$type} if exists $convertImageType{$type};

        my $image = pdflib_pl::PDF_open_image_file($context->{PDF}, $type, $txt, '', 0);
        $image == -1 and die "Cannot open <image> file '$txt'", $/;

        $context->store_image($txt, $image);

        $self->{IMAGE_HEIGHT} = pdflib_pl::PDF_get_value($context->{PDF}, 'imageheight', $image);
        $self->{IMAGE_WIDTH}  = pdflib_pl::PDF_get_value($context->{PDF}, 'imagewidth', $image);

        die "Image '$txt' has 0 (or less) height.", $/ if $self->{IMAGE_HEIGHT} <= 0;
        die "Image '$txt' has 0 (or less) width.", $/  if $self->{IMAGE_WIDTH} <= 0;
    }

    return 1;
}

sub render
{
    my $self = shift;
    my ($context) = @_;

    return 0 unless $self->should_render($context);

    return 1 if $context->{CALC_LAST_PAGE};

    my $txt = $context->get($self, 'FILENAME') ||
        $self->{TXTOBJ}->resolve($context) ||
        die "Image does not have a filename", $/;

    my $image = $context->retrieve_image($txt);
    $image == -1 && die "Image not found for '$txt' when <image> is rendered.", $/;

    $self->set_values($context, $txt);

    my ($x, $y, $scale) = map { $context->get($self, $_) } qw(X Y SCALE);

    pdflib_pl::PDF_place_image(
        $context->{PDF},
        $image, $x, $y, $scale,
    );

    if ($context->get($self, 'BORDER'))
    {
        pdflib_pl::PDF_save($context->{PDF});

        $self->set_color($context, 'COLOR', 'both');

        my ($w, $h) = map { $context->get($self, $_) } qw(W H);

        pdflib_pl::PDF_rect(
            $context->{PDF},
            $x, $y, $w, $h,
        );
        pdflib_pl::PDF_stroke($context->{PDF});

        pdflib_pl::PDF_restore($context->{PDF});
    }

    return 1;
}

sub set_values
{
    my $self = shift;
    my ($context, $txt) = @_;

    my $scale = $context->get($self, 'SCALE');

    if (defined $scale)
    {
        die "Scale is zero or less when rendering <image> '$txt'.", $/ if $scale <= 0;
        $self->{W} = $self->{IMAGE_WIDTH}  * $scale;
        $self->{H} = $self->{IMAGE_HEIGHT} * $scale;
    }
    else
    {
        my ($w, $h) = map { $context->get($self, $_) } qw(W H);
        if (defined $w && defined $h)
        {
            die "Height of zero or less in <image> '$txt'.", $/ if $h <= 0;
            die "Width of zero or less in <image> '$txt'.", $/ if $w <= 0;

            my $test_scale = $w / $h;
            if ($test_scale == ($self->{IMAGE_WIDTH}/$self->{IMAGE_HEIGHT}))
            {
                $self->{SCALE} = $test_scale;
            }
            else
            {
                undef $h;
            }
        }

        if (defined $w)
        {
            $self->{SCALE} = $w / $self->{IMAGE_WIDTH};
            $self->{H} = $self->{IMAGE_HEIGHT} * $scale;
        }
        elsif (defined $h)
        {
            $self->{SCALE} = $h / $self->{IMAGE_HEIGHT};
            $self->{W} = $self->{IMAGE_WIDTH} * $scale;
        }
        else
        {
            $self->{SCALE} = 0.5;
            $self->{W} = $self->{IMAGE_WIDTH}  * $self->{SCALE};
            $self->{H} = $self->{IMAGE_HEIGHT} * $self->{SCALE};
        }
    }

    return 1;
}

1;
__END__

=head1 NAME

PDF::Template::Element::Image

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
