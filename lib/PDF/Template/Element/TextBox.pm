package PDF::Template::Element::TextBox;

use strict;

BEGIN {
    use vars qw(@ISA);
    @ISA = qw(PDF::Template::Element);

    use PDF::Template::Element;

UNI_YES    use Unicode::String;
}

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->{TXTOBJ} = PDF::Template::Factory->create('TEXTOBJECT');

    return $self;
}

sub get_text
{
    my $self = shift;
    my ($context) = @_;

    my $txt = $context->get($self, 'TEXT');
    if (defined $txt)
    {
        my $txt_obj = PDF::Template::Factory->create('TEXTOBJECT');
        push @{$txt_obj->{STACK}}, $txt;
        $txt = $txt_obj->resolve($context);
    }
    elsif ($self->{TXTOBJ})
    {
        $txt = $self->{TXTOBJ}->resolve($context)
    }
    else
    {
UNI_YES        $txt = Unicode::String::utf8('');
UNI_NO         $txt = '';
    }

    return $txt;
}

sub render
{
    my $self = shift;
    my ($context) = @_;

    delete $self->{TEMP_H} if exists $self->{TEMP_H};

    return 0 unless $self->should_render($context);

    if ($context->{CALC_LAST_PAGE})
    {
        $self->{TEMP_H} = $self->calculate($context, 'H');
        return 1;
    }

    my $x = $context->get($self, 'X');
    my $y = $context->get($self, 'Y');
    my $w = $context->get($self, 'W');
    my $h = $context->get($self, 'H');

    my $justify = $context->get($self, 'JUSTIFY') || $context->get($self, 'ALIGN');
    $self->_validate_option('JUSTIFY', \$justify);

    $self->set_color($context, 'COLOR', 'both');

    if (defined(my $lmargin = $context->get($self, 'LMARGIN')))
    {
        $x += $lmargin;
        $w -= $lmargin;
    }

    if (defined(my $rmargin = $context->get($self, 'RMARGIN')))
    {
        $w -= $rmargin;
    }

    my $txt = $self->get_text($context);

    $self->{TEMP_H} = $self->show_boxed(
        $context, $txt,
        $x, $y, $w, $h,
        $justify, '',
    );

    if ($context->get($self, 'BGCOLOR'))
    {
        pdflib_pl::PDF_save($context->{PDF});

        $self->set_color($context, 'BGCOLOR', 'fill');

        pdflib_pl::PDF_rect($context->{PDF}, $x, $y - $self->{TEMP_H} + $h, $w, $self->{TEMP_H});
        pdflib_pl::PDF_fill($context->{PDF});
        pdflib_pl::PDF_restore($context->{PDF});
    }

    if ($context->get($self, 'BORDER'))
    {
        pdflib_pl::PDF_rect($context->{PDF}, $x, $y - $self->{TEMP_H} + $h, $w, $self->{TEMP_H});
        pdflib_pl::PDF_stroke($context->{PDF});
    }

    $self->set_color($context, 'COLOR', 'both', 1);

    return 1;
}

sub deltas
{
    my $self = shift;
    my ($context) = @_;

    return {
        X => $context->get($self, 'W'),
        Y => 0,
    };
}

sub _display_doublebyte
{
    my $self = shift;
    my ($p, $str, $x, $y, $j, $font_size) = @_;

    if ($j eq 'right')
    {
UNI_YES        $x -= $str->length * $font_size;
UNI_NO         $x -= length($str) * $font_size;
    }
    elsif ($j eq 'center')
    {
UNI_YES        $x -= ($str->length / 2) * $font_size;
UNI_NO         $x -= (length($str) / 2) * $font_size;
    }

UNI_YES    Unicode::String->stringify_as('ucs2');
UNI_YES    pdflib_pl::PDF_show_xy($p, $str->as_string, $x, $y);
UNI_NO     pdflib_pl::PDF_show_xy($p, $str, $x, $y);

    return 0;
}

sub _show_boxed
{
    my $self = shift;
    my $context = shift;

    my $encoding = $context->get($self, 'PDF_ENCODING') || 'host';
    if ($encoding eq 'host')
    {
UNI_YES        Unicode::String->stringify_as('latin1');
UNI_NO         my $str = shift;
UNI_YES        my $leftovers = pdflib_pl::PDF_show_boxed($context->{PDF}, $str->as_string, @_);
UNI_NO         my $leftovers = pdflib_pl::PDF_show_boxed($context->{PDF}, $str, @_);

UNI_YES        $leftovers++ if $leftovers && $leftovers == $str->length - 1;
UNI_NO         $leftovers++ if $leftovers && $leftovers == length($str) - 1;
        return $leftovers;
    }

    my ($p, $str, $x, $y, $w, $h, $j, $m) = ($context->{PDF}, @_);

    my $font_size = pdflib_pl::PDF_get_value($p, 'fontsize', undef);
    die "Fontsize of 0!", $/ if $font_size <= 0;

    if ($w == 0 && $h == 0)
    {
        return 0 if $m eq 'blind';
        return $self->_display_doublebyte($p, $str, $x, $y, $j, $font_size);
    }

    my $num_lines = int($h / $font_size);
    my $chars_per_line = int($w / $font_size);

    my $right = $x + $w;
    my $mid    = int(($x + $right) / 2);

    my $current_y = $y + $h - $font_size;

    foreach my $line_num (0 .. $num_lines - 1)
    {
        my $start_x = $x;
        $start_x = $right if $j eq 'right';
        $start_x = $mid if $j eq 'center';

UNI_YES        if ($str->length <= $chars_per_line)
UNI_NO         if (length($str) <= $chars_per_line)
        {
            return 0 if $m eq 'blind';
            return $self->_display_doublebyte($p, $str, $start_x, $current_y, $j, $font_size);
        }

UNI_YES        my $str_this_line = $str->substr(0, $chars_per_line);
UNI_NO         my $str_this_line = substr($str, 0, $chars_per_line);

        $self->_display_doublebyte($p, $str_this_line, $start_x, $current_y, $j, $font_size)
            unless $m eq 'blind';

        $current_y -= $font_size;
UNI_YES        $str = $str->substr($chars_per_line);
UNI_NO         $str = substr($str, $chars_per_line);
    }

UNI_YES    return $str->length;
UNI_NO     return length($str);
}

sub show_boxed
{
    my $self = shift;
    my ($context, $str, $x, $y, $w, $h, $justify, $mode) = @_;

    my $fsize = pdflib_pl::PDF_get_value($context->{PDF}, "fontsize", undef);
    $fsize = 0 if $fsize < 0;

UNI_YES    return $h unless $str->length && ($fsize && $h / $fsize >= 1);
UNI_NO     return $h unless length($str) && ($fsize && $h / $fsize >= 1);

    my $total_h = $h;
UNI_YES    my $excess_txt = Unicode::String::utf8('');
UNI_NO     my $excess_txt = '';

    LOOP:
    {
        my $leftovers = $self->_show_boxed(
            $context, $str,
            $x, $y, $w, $h,
            $justify, $mode,
        );
        die "Invalid return ($leftovers) from pdflib_pl::PDF_show_boxed() on string '$str'", $/
UNI_YES            if $leftovers > $str->length;
UNI_NO             if $leftovers > length($str);

        last LOOP if $context->get($self, 'TRUNCATE_TEXT');

UNI_YES        if ($leftovers < $str->length)
UNI_NO         if ($leftovers < length($str))
        {
            last LOOP unless $excess_txt || $leftovers;

UNI_YES            $str = ($leftovers ? $str->substr(-1 * $leftovers) : '' ) . $excess_txt;
UNI_NO             $str = ($leftovers ? substr($str, -1 * $leftovers) : '' ) . $excess_txt;
            $excess_txt = '';

UNI_YES            $str = $str->substr(1) while $str->substr(0, 1) =~ /^[\r\n\s]+/o;
UNI_NO             $str =~ s/^[\r\n\s]+//go;

            $y -= $h;
            $total_h += $h;

            redo LOOP;
        }

        last LOOP unless $leftovers;

UNI_YES        $excess_txt = $str->chop . $excess_txt;
UNI_YES        $excess_txt = $str->chop . $excess_txt
UNI_YES            while $str->substr(-1) =~ /^[\r\n\s]$/o;
UNI_NO         $excess_txt = chop($str) . $excess_txt;
UNI_NO         $excess_txt = chop($str) . $excess_txt
UNI_NO             while $str =~ /[\r\n\s]$/o;

        redo LOOP;
    }

    return $total_h;
}

sub calculate
{
    my $self = shift;
    my ($context, $attr) = @_;

    return $self->SUPER::calculate($context, $attr) unless $attr eq 'H';

    return delete $self->{TEMP_H} if exists $self->{TEMP_H};

    my $txt = $self->get_text($context);

    return $self->show_boxed(
        $context, $txt,
        (map { $context->get($self, $_) } qw(X Y W H)),
        'left', 'blind',
    );
}

1;
__END__

=head1 NAME

PDF::Template::Element::TextBox

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
