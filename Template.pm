package PDF::Template;

use pdflib_pl 3.02;
use XML::Parser;

use Data::Dumper;  # temp (appears below numerous times too :( )

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
   
);
$VERSION = '0.02';

sub debug
{
   print @_;
}


#
#-----------------------------------------------
# TODO
#-----------------------------------------------
# conditional - test with nested loops in it
# move font finding stuff to font->begin_page
# TODO should be ::Container::Pagedef
# loop maxiters
# PDF_set_info - find out more about this
# Need to make ALREADYDONE as clear as PENDINGBREAK is
#   - Added loop variable __PAGEFIRST__
# Providers - I need to create some provider classes that abstract
#   the process of PDF creation.  This will enable PDF::Template to
#   work with different PDF providers.  A provider could be passed
#   in to the constructor.  If non is passed, P::T should try to
#   instantiate a sensible provider depending on what is installed.
#-----------------------------------------------
#

# FILENAME
#
sub new 
{
   my $proto = shift;
   my $class = ref($proto) || $proto;

   my $self = {
      PAGEDEFS => [],
      PARAM_MAP => {},
      OPENACTION => 'fitpage',
      OPENMODE=>'none'
      
   };

   # load in options supplied to new()
   for (my $x = 0; $x <= $#_; $x += 2) 
   {
      my $opt = uc($_[$x]);
      defined($_[($x + 1)]) or die "PDF::Template->new() called with odd number of option parameters - should be of the form option => value";
      $self->{$opt} = $_[($x + 1)]; 
   }

   bless($self);

   if (defined($self->{FILENAME}))
   {
      $self->_parse_xml($self->{FILENAME});
   }

   return $self;

}


##### Pass parameters to the report.  Similar to
#     HTML::Template's param().
#
sub param
{
   my $self = shift;
   my $param_map = $self->{PARAM_MAP};

   my $first = shift;
   my $type = ref $first;

   if (!scalar(@_)) 
   {
      croak("HTML::Template->param() : Single reference arg to param() must be a hash-ref!  You gave me a $type.")
      unless $type eq 'HASH' or 
        (ref($first) and UNIVERSAL::isa($first, 'HASH'));  
      push(@_, %$first);
   } 
   else 
   {
      unshift(@_, $first);
   }
   
   croak("PDF::Template->param() : You gave me an odd number of parameters to param()!")
    unless ((@_ % 2) == 0);

   for (my $x = 0; $x <= $#_; $x += 2) 
   {
      my $param = $_[$x];
      my $value = $_[($x + 1)];
      my $value_type = ref($value);

      if (defined($value_type) and length($value_type) and ($value_type eq 'ARRAY' or ((ref($value) !~ /^(CODE)|(HASH)|(SCALAR)$/) and $value->isa('ARRAY')))) 
      {
         $param_map->{$param} = $value;
      } 
      else 
      {
         $param_map->{$param} = $value;
      }

   }
   
#print Dumper($param_map);
}


sub write_file
{
   my ($self,$fname) = @_;
   my $p = PDF_new();

   die "PDF_open_file could not open file \"$fname\"\n"
      if (PDF_open_file($p,$fname) == -1);
      
   $self->_prepare_output($p);
   PDF_close($p);
}

sub get_buffer
{
   my ($self) = @_;
   my $p = PDF_new();

   die "PDF_open_file could not open file...\n"
      if (PDF_open_file($p,'') == -1);

   $self->_prepare_output($p);

   my $buf = PDF_get_buffer($p);

   PDF_close($p);
   
   $buf;
}


sub _parse_xml
{
   my ($self,$fname) = @_;
   
   my $parser = new XML::Parser(Style=>"Tree");
   my $out = $parser->parsefile($fname);

   # So this should be an array ref of tag content pairs
   # Actually, this being the top level object, there should be only
   # one....
   for (my $x = 0; $x <= $#{$out}; $x += 2) 
   {
      my $tag = uc($out->[$x]);

      defined($out->[($x + 1)]) or die "PDF::Template->parse_xml() called with odd number of option parameters - should be of the form option => value";
      my $aref = $out->[$x+1];

      my $href = shift @{$aref};   # attributes - nothing so far...

      for my $k (keys (%{$href})) 
      { 
         $self->{uc($k)} = $href->{$k}; 
      }
      
      # Process elements
      for (my $y=0; $y <= $#{$aref}; $y+=2)
      {
         my $tag = uc($aref->[$y]);
         
         if ($tag eq 'PAGEDEF')
         {
            my $xref = $aref->[$y+1];
            my $href = shift @{$xref};
            my $pd = PDF::Template::PageDef->new(%{$href});
            $pd->_parse_xml($xref);
            $self->add_pagedef($pd);
         }
         # else ignore text tags.....
      }

   }

#   print Dumper($out);
}

sub add_pagedef
{
   my ($self,$pdref) = @_;
   push @{$self->{PAGEDEFS} } , $pdref;
}

sub _prepare_output
{
   my ($self,$p) = @_;
   my $pd;

   # retain, fitpage, fitwidth, fitheight, fitbox
   PDF_set_parameter($p, 'openaction',$self->{OPENACTION});

   # none, bookmarks, thumbnails, fullscreen
   PDF_set_parameter($p, 'openmode',$self->{OPENMODE});
   
   # TODO: Make these attributes!!!
   PDF_set_info($p, "Creator", "HRDatamine");
   PDF_set_info($p, "Author", "Levy & Associates, Inc.");

   my %handles = (
      FONTS => {},
      IMAGES => {},
      PARAM_MAP => $self->{PARAM_MAP},
      GLOBALS => {
         '__PAGE__' => '1'
# 'Y' is intentionally undefined
         }
   );


   # Render each of our pagedefs
   for $pd (@{$self->{PAGEDEFS}})
   {
      $pd->render($p,\%handles);
   }

   for my $k (keys( %{$handles{IMAGES}} ) )
   {
      pdflib_pl::PDF_close_image($p,$handles{IMAGES}->{$k});
   }
   
}



########################################################################
package PDF::Template::PageDef;
########################################################################

use vars qw(@ISA);
@ISA = qw(PDF::Template::Container::Base);

sub new
{
   my $proto = shift;
   my $class = ref($proto) || $proto;

   my $self = {
      ELEMENTS => [],
      NOPAGENUMBER => 0
   };

   # load in options supplied to new()
   for (my $x = 0; $x <= $#_; $x += 2) 
   {
      my $opt = uc($_[$x]);
      
      defined($_[($x + 1)]) or die "PDF::Template->new() called with odd number of option parameters - should be of the form option => value";
      $self->{$opt} = $_[($x + 1)]; 
   }

   # default to normal paper size in US
   if (!defined($self->{PAGESIZE})) { $self->{PAGESIZE} = 'A4'; }

   if ( $self->{PAGESIZE} eq 'A0')
   {
      $self->{WIDTH} = 2380;
      $self->{HEIGHT} = 3368;
   }
   elsif ( $self->{PAGESIZE} eq 'A1')
   {
      $self->{WIDTH} = 1684;
      $self->{HEIGHT} = 2380;
   }
   elsif ( $self->{PAGESIZE} eq 'A2')
   {
      $self->{WIDTH} = 1190;
      $self->{HEIGHT} = 1684;
   }
   elsif ($self->{PAGESIZE} eq 'A3')
   {
      $self->{WIDTH} = 1190;
      $self->{HEIGHT} = 842;
   }
   elsif ( $self->{PAGESIZE} eq 'A4')  
   {
      $self->{WIDTH} = 595;
      $self->{HEIGHT} = 842;
   }

   # swap dimensions if landscape
   if (defined($self->{LANDSCAPE}) && $self->{LANDSCAPE}==1)
   {
      my $tmp = $self->{WIDTH};
      $self->{WIDTH} = $self->{HEIGHT};
      $self->{HEIGHT} = $tmp;
   }
   
   bless($self);
   return $self;

}

sub render
{
   my ($self,$p,$r_handles) = @_;
   my $er;

   my $notdone = 1;
   
   my $max_elem = -1;  # Highest succesfully rendered element
   
   while ($notdone)
   {
      $notdone = 0;

      # Pendingbreak gets set to 1 when we hit a page break.
      $r_handles->{PENDINGBREAK} = 0;

      # ALREADY_DONE gets set to 1 when we are redinering elements
      # that have already be rendered.  This happens after a page
      # break.  If an element is not in an always block, it should 
      # see that ALREADYY_DONE is set and not render itself.  ALWAYS
      # blocks should render regardless.
      
      $r_handles->{ALREADY_DONE} = 1;
      
      my $ref_fonts = $r_handles->{FONTS};   

      $self->_begin_page($p,$r_handles);
      
      pdflib_pl::PDF_begin_page($p,$self->{WIDTH},$self->{HEIGHT});


      #TODO: move to font::_begin_page
      my $key;
      for $key (keys %{$ref_fonts})
      {
         $ref_fonts->{$key} = pdflib_pl::PDF_findfont($p,$key,"host",0);
      }


      my $cur_elem = 0;
      
      for $er ( @{$self->{ELEMENTS}} )
      {
         if ($cur_elem >= $max_elem)
         {
            $r_handles->{ALREADY_DONE} = 0;
         }
         
         $notdone += $er->render($p,$r_handles);

         if ($notdone)
         {
            $r_handles->{PENDINGBREAK} = 1;
         }
         # If successful, keep track of this fact
         elsif ($cur_elem > $max_elem)
         {
            $max_elem = $cur_elem;
         }
         $cur_elem ++;
      }

      $self->_end_page($p,$r_handles);
      
      pdflib_pl::PDF_end_page($p);

      if ($self->{NOPAGENUMBER} != 1)
      {
         $r_handles->{GLOBALS}->{'__PAGE__'}++;
      }

      delete $r_handles->{GLOBALS}->{Y};

   }   
}


########################################################################
package PDF::Template::TextObject;
########################################################################

#
# This is a helper object.  It is not instantiated by the user, 
# nor does it represent an XML object.  Rather, certain elements, 
# such as the textbox, can use this object to do text with variable
# substitutions.
#
sub new
{
   my $proto = shift;
   my $class = ref($proto) || $proto;

   my $self = {
      STACK => []
   };
   
   bless $self;
}

sub resolve
{
   my ($self,$r_handles) = @_;
   my $t;
   my $stack = $self->{STACK};
   
   for my $k (@{$stack})
   {
      if ($k->{TYPE} eq 'TXT') 
      {
         $t .= $k->{VAL};
      }
      elsif ($k->{TYPE} eq 'VAR')
      {
         $t .= $k->{VAL}->resolve($r_handles);
      }
   }

   $t;
}

sub _parse_xml
{
   my ($self,$xref) = @_;
   
   my $stack = $self->{STACK};
   
   # Process elements
   for (my $y=0; $y <= $#{$xref}; $y+=2)
   {
      my $tag = uc($xref->[$y]);

      if ($tag eq '0')
      {
         push @{$stack}, { TYPE=>'TXT', VAL=>$xref->[$y+1] };
      }
      if ($tag eq 'VAR')
      {
         my $aref = $xref->[$y+1];
         my $href = shift @{$aref};
         my $v = PDF::Template::Var->new(%{$href});
         $v->_parse_xml($aref);
         push @{$stack}, { TYPE=>'VAR', VAL=>$v };
      }
   }
#print Dumper($self);
   
}


########################################################################
package PDF::Template::Container::Base;
########################################################################

# Containers are objects that can contain arbitrary elements, such as
# PageDefs or Loops.

# Tables are not containers because the contain specific elements.  Or
# are they?

sub new
{
   my $proto = shift;
   my $class = ref($proto) || $proto;

   my $self = {
      ELEMENTS => []
   };

   # load in options supplied to new()
   for (my $x = 0; $x <= $#_; $x += 2) 
   {
      my $opt = uc($_[$x]);
      
      defined($_[($x + 1)]) or die "PDF::Template::Container->new() called with odd number of option parameters - should be of the form option => value";
      $self->{$opt} = $_[($x + 1)]; 
   }

   bless($self);
   return $self;

}


sub _begin_page
{
   my ($self,$p,$hr_handles) = @_;
   
   ##### Let the elements do any beginning of page stuff
   for my $er ( @{$self->{ELEMENTS}} )
   {
      $er->_begin_page($p,$hr_handles);
   }

}

sub _end_page
{
   my ($self,$p,$hr_handles) = @_;
   
   ##### Let the elements do any end of page stuff
   for my $er ( @{$self->{ELEMENTS}} )
   {
      $er->_end_page($p,$hr_handles);
   }

}


sub _parse_xml
{
   my ($self,$xref) = @_;

   # Process elements
   for (my $y=0; $y <= $#{$xref}; $y+=2)
   {
      my $tag = uc($xref->[$y]);

      next if ($tag eq '0');
      
      my $aref = $xref->[$y+1];
      my $href = shift @{$aref};
      my $t;
      
      if ($tag eq 'TEXTBOX')
      {
         $t = PDF::Template::Element::TextBox->new(%{$href});
      }
      elsif ($tag eq 'IMAGE')
      {
         $t = PDF::Template::Element::Image->new(%{$href});
      }
      elsif ($tag eq 'FONT')
      {
         $t = PDF::Template::Element::Font->new(%{$href});
      }
      elsif ($tag eq 'LINE')
      {
         $t = PDF::Template::Element::Line->new(%{$href});
      }
      elsif ($tag eq 'LOOP')
      { 
         $t = PDF::Template::Container::Loop->new(%{$href});
      }
      elsif ($tag eq 'ROW')
      {
         $t = PDF::Template::Container::Row->new(%{$href});
      }
      elsif ($tag eq 'IF')
      {
         $t = PDF::Template::Container::Conditional->new(%{$href});
      }
      elsif ($tag eq 'PAGE-BREAK')
      {
         $t = PDF::Template::Element::PageBreak->new(%{$href});
      }
      elsif ($tag eq 'BOOKMARK')
      {
         $t = PDF::Template::Element::Bookmark->new(%{$href});
      }
      elsif ($tag eq 'POS')
      {
         $t = PDF::Template::Element::Pos->new(%{$href});
      }
      elsif ($tag eq 'ALWAYS')
      {
         $t = PDF::Template::Container::Always->new(%{$href});
      }
      
      
      if (defined($t))
      {
         $t->_parse_xml($aref);
         $self->add_element($t);
      }
      
      # else ignore text tags.....
   }
   
}

sub add_element
{
   my ($self,$eref) = @_;
   push @{ $self->{ELEMENTS} } , $eref;
}

# experiment
sub set_y_base
{
   my ($self,$ybase) = @_;
   $self->{Y_BASE} = $ybase;
}

sub y
{
   my ($self) = @_;
   my $y = $self->{Y};
   $y += $y->{Y_BASE} if (defined($self->{Y_BASE}));
   $y;
}


########################################################################
package PDF::Template::Element::Base;
########################################################################

sub new
{
   my $proto = shift;
   my $class = ref($proto) || $proto;

   my $self = {
   };

   # load in options supplied to new()
   for (my $x = 0; $x <= $#_; $x += 2) 
   {
      my $opt = uc($_[$x]);
      
      defined($_[($x + 1)]) or die "$class->new() called with odd number of option parameters - should be of the form option => value";
      $self->{$opt} = $_[($x + 1)]; 
   }

   bless($self);
   return $self;

}


# Return non zero if we will need more pages
sub render
{
   my ($self,$p, $r_handles) = @_;
   0;   
}

sub _begin_page
{
   my ($self,$p,$r_handles) = @_;
}

sub _end_page
{
   my ($self,$p,$r_handles) = @_;
}

sub _parse_xml
{
   my ($self,$xref) = @_;   
}

sub set_y_base
{
   my ($self,$ybase) = @_;
   $self->{Y_BASE} = $ybase;
}

sub y
{
   my ($self) = @_;
   my $y = $self->{Y};
   $y += $self->{Y_BASE} if (defined($self->{Y_BASE}));
   $y;
}








########################################################################
package PDF::Template::Element::TextBox;
########################################################################

use vars qw(@ISA);
@ISA = qw (PDF::Template::Element::Base);

use Data::Dumper;

sub new
{
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = $class->SUPER::new(@_);

   bless($self,$class);

   $self->{TXTOBJ} = PDF::Template::TextObject->new();
   
   if (!defined($self->{JUSTIFY})) { $self->{JUSTIFY}='left'; }

   return $self;
}

sub render
{
   my ($self,$p, $r_handles) = @_;

   if ($r_handles->{PENDINGBREAK})
   {
      return 1;
   }

   if ($r_handles->{ALREADY_DONE}) { return 0; }

   my $ref_fonts     = $r_handles->{FONTS};
   my $ref_param_map = $r_handles->{PARAM_MAP};

   my $ref_loop_info = $r_handles->{INNER};   
   if (defined($ref_loop_info) && $ref_loop_info->{ALREADY_DONE}==1) {
      return 0;
   }

   # Variable Substitution
   my $txt = $self->{TXTOBJ}->resolve($r_handles);
   
   my $x = $self->{X};
   my $y = $self->y();
   my $w = $self->{W};
   my $h = $self->{H};
   
   if (!defined($x))
   {
      $x = pdflib_pl::PDF_get_value($p,'textx',0);
   }

#print "print: ^$txt^\n";
#print "pos: x $x y $y \n"; 

   # PDFLIB Note:  It appears that PDFLib does not support text
   # in any color other than black.

   if (defined($self->{BGCOLOR}))
   {
      my ($r,$g,$b) = split ',' , $self->{BGCOLOR};
      pdflib_pl::PDF_setrgbcolor_fill($p,$r/255,$g/255,$b/255);
      pdflib_pl::PDF_rect($p,$x,$y,$w,$h);
      pdflib_pl::PDF_fill($p);
      pdflib_pl::PDF_setrgbcolor_fill($p,0,0,0);
   }
   
   if (defined($self->{BORDER}))
   {
      pdflib_pl::PDF_rect($p,$x,$y,$w,$h);
      pdflib_pl::PDF_stroke($p);
   }

   if (defined($self->{LMARGIN}))
   {
      $x += $self->{LMARGIN};
      $w -= $self->{LMARGIN};
   }
   
   if (defined($self->{RMARGIN}))
   {
      $w -= $self->{RMARGIN};
   }

   # OK, print that
   pdflib_pl::PDF_show_boxed($p,$txt,
                  $x,$y,
                  $w,$h,
                  $self->{JUSTIFY},
                  ''
                  );   
                  

   # PDF_Show_Boxed screws up the text pointer.  It appears to move
   # ***UP*** the page instead of down.
   # So put it where it should be here.
   #   pdflib_pl::PDF_set_text_pos($p,$x,$y-$self->{H});
   
    0;
}

sub _parse_xml
{
   my ($self,$xref) = @_;
   $self->{TXTOBJ}->_parse_xml($xref);
}


########################################################################
package PDF::Template::Var;
########################################################################


use vars qw(@ISA);
@ISA=qw(PDF::Template::Element::Base);

sub new
{
   my $proto = shift;
   my $class = ref($proto) || $proto;

   my $self = {
   };

   # load in options supplied to new()
   for (my $x = 0; $x <= $#_; $x += 2) 
   {
      my $opt = uc($_[$x]);      
      defined($_[($x + 1)]) or die "PDF::Template::Element::Base->new() called with odd number of option parameters - should be of the form option => value";
      $self->{$opt} = $_[($x + 1)]; 
   }
   bless($self);
   return $self;
}

sub resolve
{
   my ($self,$r_handles) = @_;
   my $ref_param_map = $r_handles->{PARAM_MAP};
   my $ret = '';
   
   if ($self->{NAME} =~ /__.*__/)
   {
      $ret = $r_handles->{GLOBALS}->{$self->{NAME}};
   }
   else
   {
      $ret = $ref_param_map->{$self->{NAME}};
   }
   
   $ret;
}

########################################################################
package PDF::Template::Element::Font;
########################################################################

use vars qw(@ISA);
@ISA = qw(PDF::Template::Element::Base);

sub new
{
   my $proto = shift;
   my $class = ref($proto) || $proto;

   my $self = {
      FACE=>'Times-Bold',
      SIZE=>12
   };

   # load in options supplied to new()
   for (my $x = 0; $x <= $#_; $x += 2) 
   {
      my $opt = uc($_[$x]);
      
      defined($_[($x + 1)]) or die "PDF::Template::Textbox->new() called with odd number of option parameters - should be of the form option => value";
      $self->{$opt} = $_[($x + 1)]; 
   }

   bless($self);
   return $self;
}


sub render
{
   my ($self,$p, $r_handles) = @_;


   if ($r_handles->{PENDINGBREAK})
   {
      return 1;
   }
   
   my $face = $self->{FACE};
   my $size = $self->{SIZE};
   my $ref_fonts = $r_handles->{FONTS};
      
   pdflib_pl::PDF_setfont($p,$ref_fonts->{$face},$size);
   0;
}

sub _begin_page
{
   my ($self,$p,$r_handles) = @_;
   my $path = $self->{PATH};

   $r_handles->{FONTS}->{$self->{FACE}} = '';
   
}


########################################################################
package PDF::Template::Element::Line;
########################################################################

use vars qw(@ISA);
@ISA=qw(PDF::Template::Element::Base);

sub new 
{
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = $class->SUPER::new(@_);
   bless ($self,$class);   
}

sub render
{
   my ($self,$p, $r_handles) = @_;

   if ($r_handles->{PENDINGBREAK})
   {
      return 1;
   }

   pdflib_pl::PDF_setlinewidth($p,1);
   pdflib_pl::PDF_moveto($p,$self->{X1},$self->{Y1});
   pdflib_pl::PDF_lineto($p,$self->{X2},$self->{Y2});
   pdflib_pl::PDF_stroke($p);

   0;   
}


########################################################################
package PDF::Template::Element::Pos;
########################################################################

# This is still an experimental element.
# Add X info?  Add relative movement?  I don't know.

use vars qw(@ISA);
@ISA=qw(PDF::Template::Element::Base);

sub new 
{
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = $class->SUPER::new(@_);
   bless ($self,$class);   
}

sub render
{
   my ($self,$p, $r_handles) = @_;

   $r_handles->{GLOBALS}->{Y} = $self->{Y};
   
   0;   
}


########################################################################
package PDF::Template::Element::PageBreak;
########################################################################

use vars qw(@ISA);
@ISA=qw(PDF::Template::Element::Base);

sub new 
{
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = $class->SUPER::new(@_);
   bless ($self,$class);   
   $self->{TOGGLE} = 0;
   return $self;
}
sub render
{
   my ($self,$p, $r_handles) = @_;
   my $ref_loop_info = $r_handles->{INNER};
   
   if (defined($ref_loop_info) && $ref_loop_info->{ALREADY_DONE}==1)
   {
      return 0;
   }

   if ($self->{TOGGLE} == 1)
   {
      $self->{TOGGLE} = 0;
      return 0;
   }
   
   $self->{TOGGLE} = 1;
   1;   
}


########################################################################
package PDF::Template::Element::Bookmark;
########################################################################

use vars qw(@ISA);
@ISA=qw(PDF::Template::Element::Base);

sub new 
{
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = $class->SUPER::new(@_);
   bless ($self,$class);   
   $self->{TXTOBJ} = PDF::Template::TextObject->new();
   return $self;
}
sub render
{
   my ($self,$p, $r_handles) = @_;
   my $ref_param_map = $r_handles->{PARAM_MAP};
   my $ref_loop_info = $r_handles->{INNER};

   my $txt = $self->{TXTOBJ}->resolve($r_handles);
   
   if (!defined($txt))
   {
      warn "Bookmark: no text defined!\n";
      $txt = 'undefined';
   }

   if ($ref_loop_info->{ALREADY_DONE} == 0)
   {
       pdflib_pl::PDF_add_bookmark($p,$txt,0,0);   
   }
   
   0;    # Never requires more processing
}

sub _parse_xml
{
   my ($self,$xref) = @_;
   $self->{TXTOBJ}->_parse_xml($xref);
}


########################################################################
package PDF::Template::Element::Image;
########################################################################

use vars qw(@ISA);
@ISA=qw(PDF::Template::Element::Base);

sub new
{
   my $proto = shift;
   my $class = ref($proto) || $proto;

   my $self = {
      X => 0,
      Y => 0,
      SCALE => 0.5,
      PATH => ''
   };


   $self->{TXTOBJ} = PDF::Template::TextObject->new();

   # load in options supplied to new()
   for (my $x = 0; $x <= $#_; $x += 2) 
   {
      my $opt = uc($_[$x]);
      
      defined($_[($x + 1)]) or die "PDF::Template::Element::Image->new() called with odd number of option parameters - should be of the form option => value";
      $self->{$opt} = $_[($x + 1)]; 
   }

   bless($self);
   return $self;

}


sub render
{
   my ($self,$p, $r_handles) = @_;

   if ($r_handles->{PENDINGBREAK})
   {
      return 1;
   }

   my $txt = $self->{TXTOBJ}->resolve($r_handles);
   my $i = $r_handles->{IMAGES}->{$txt};
   
   pdflib_pl::PDF_place_image($p, 
                   $i, 
                   $self->{X},
                   $self->y(), 
                   $self->{SCALE}
                   );

   0;   
}


sub _begin_page
{
   my ($self,$p,$r_handles) = @_;
   my $type = lc($self->{TYPE});
   
   my $txt = $self->{TXTOBJ}->resolve($r_handles);
   my $image = pdflib_pl::PDF_open_image_file($p,$type,$txt,"", 0);
   
   $r_handles->{IMAGES}->{$txt} = $image;

}


sub _parse_xml
{
   my ($self,$xref) = @_;
   $self->{TXTOBJ}->_parse_xml($xref);
}




########################################################################
package PDF::Template::Container::Loop;
########################################################################

use vars qw(@ISA);
@ISA = qw (PDF::Template::Container::Base);

use Data::Dumper;

sub new
{
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = $class->SUPER::new(@_);
   bless $self,$class;
   
##      MAXITERS=>undef,  leave undefined

   $self->{DATAIDX} = 0;
   $self->{ELEMIDX} = 0;
   
   return $self;
}

# container::loop::render()
#
# The local variable $y tracks our $y position on the page.
# I'd love to use the internal pointer but it is updated in
# arbitrary ways, and anyway there are two, one for graphics
# and one for text.
#
# So I have some problems:
#   1.  Passing the $y variable into inner loops and back.  This
#       is probably best dealt with in $r_handles.
#   2.  How and when to update it.
#       a.  At the beginning of a page :)
#       b.  After elements (not containers)?
#   3.  Specifying positions in terms of offsets from the current Y
#       in all elements.
#       a.  One approach: X,W,H are absolute.  Y is assumed relative?
#           Fails since we don't know if we are in a container or not.
#           Or we could have a Y_BASE attribute to be added to Y when it
#           is defined.  This is workable.
#

sub render
{
   my ($self,$p, $r_handles) = @_;
   my ($hr);
   
   my $ref_param_map = $r_handles->{PARAM_MAP};
   my $data = $ref_param_map->{$self->{NAME}};
   my $ref_loop_info;
   my $top_level = 0;
   
   # If we are the top level loop
   if (!defined($r_handles->{INNER}))
   {
      $r_handles->{INNER} = {
         BOTTOM => $self->{Y2}, # - $self->{H},
         ALREADY_DONE => 0
         };
      $ref_loop_info = $r_handles->{INNER};
      $top_level = 1;
   }
   # Else we are an inner loop
   else
   {
       $ref_loop_info = $r_handles->{INNER};
   }

   # Temporary measure
   if (defined($self->{Y}) && !defined($r_handles->{GLOBALS}->{Y}) ) 
   { 
      $r_handles->{GLOBALS}->{Y} = $self->{Y};
   }   

   if ($ref_loop_info->{ALREADY_DONE}==1) { return 0; }

   # verify that data is an array ref
   die "Not an array ref!\n" if ref($data) ne 'ARRAY';

   # I don't know if this will work long term, but what I'm going to
   # do here is replace the PARAM_MAP in handles with just the
   # data for the loop.  I'll save the old value and then restore
   # it on the way out of this function

   # Iterate through the data
   # We store our offset into the array in DATAIDX
   my $done = 0;
   my $idx = $self->{DATAIDX};

#print "Entering loop $self->{NAME}\n";

   
   while (!$done && $idx <= $#{$data})
   {
      # Consume a row of data
      my $hr = $data->[$idx++];

      # Verify that this is a hash ref
      die "Not a hash!" if ref($hr) ne "HASH";

      # Render each of the elements / containers
      my $eidx = 0;
      my $lasteidx = $self->{ELEMIDX};
      while (!$done && $eidx <= $#{$self->{ELEMENTS}})
      {
         my $e = $self->{ELEMENTS}->[$eidx++];
         
         $r_handles->{PARAM_MAP} = $hr;

         $e->set_y_base($r_handles->{GLOBALS}->{Y});

         $ref_loop_info->{ALREADY_DONE} = ($eidx<=$lasteidx) ? 1 : 0;
         $r_handles->{GLOBALS}->{'__FIRST__'} = ($idx==0) ? 1 : 0;
         $r_handles->{GLOBALS}->{'__LAST__'} = ($idx>$#{$data}) ? 1 : 0;
         $r_handles->{GLOBALS}->{'__INNER__'} = (($idx>0)&&($idx<=$#{$data})) ? 1 : 0;
         $r_handles->{GLOBALS}->{'__ODD__'} = $idx % 2;
         
         # Let the element render         
         if ($e->render($p,$r_handles))
         {
            $done = 1;
            $idx--;
            $eidx--;
            last;
         }
         
      }

      $self->{ELEMIDX} = ($eidx>$#{$self->{ELEMENTS}}) ? 0 : $eidx;

      # Figure out if we are done (for this page instance)
      if ($r_handles->{GLOBALS}->{Y} < $ref_loop_info->{BOTTOM}) { $done = 1; }
      if ($idx > $#{$data}) { $done = 1; }

   }

   # Restore the param map value to what it should be
   $r_handles->{PARAM_MAP} = $ref_param_map;

   # Save our data index context
   # If we are done with this array, reset our index, since if this is
   # an inner loop we'll probably be called again and we want to start
   # at the beginning
   #
   $self->{DATAIDX} = ($idx>$#{$data}) ? 0 : $idx;

   if ($top_level == 1)
   {
      delete $r_handles->{INNER};
   }
   
#print "EXITING loop $self->{NAME}\n";

   
   ($idx<=$#{$data}) ? 1 : 0;
}



########################################################################
package PDF::Template::Container::Conditional;
########################################################################

use Data::Dumper;

use vars qw(@ISA);
@ISA=qw(PDF::Template::Container::Base);

# Ifs are meant to contain only elements, not containers.  Although
# it might work anyway.

sub new 
{
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = $class->SUPER::new(@_);
   bless ($self,$class);   
   $self->{IS} = uc($self->{IS});
   return $self;
}

sub render
{
   my ($self,$p, $r_handles) = @_;
   my $ref_param_map = $r_handles->{PARAM_MAP};   
   my $val;
   my $is  = $self->{IS};
   my $istrue = 0;
   my $ret = 0;

   # Determine whether or not we are going to bother rendering this conditional
   
   if ($self->{NAME} =~ /__.*__/)
   {
      $val  = $r_handles->{GLOBALS}->{$self->{NAME}};
   }
   else
   {
      $val  = $ref_param_map->{$self->{NAME}};
   }

   if ($val) { $istrue = 1; }
   
   if ($is eq 'TRUE')
   {
      if (!$istrue) { return 0; }
   }
   else
   {
      if ($is ne 'FALSE')
      {
         warn "Conditional is value was [$is], defaulting to 'FALSE'\n";
      }
      if ($istrue) { return 0; }      
   }
   
   # Render each of the elements / containers
   for my $e (@{$self->{ELEMENTS}})
   {
      if (defined($r_handles->{GLOBALS}->{Y}))
      {
         $e->set_y_base($r_handles->{GLOBALS}->{Y});
      }
      
      # Let the element render         
      if ($e->render($p,$r_handles))
      {
         $ret = 1;
         last;
      }
   }
   
   $ret;   
}




########################################################################
package PDF::Template::Container::Row;
########################################################################

use vars qw(@ISA);
@ISA = qw (PDF::Template::Container::Base);


# Rows are meant to contain only elements, not containers.  Although
# it might work anyway.


sub new
{
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = $class->SUPER::new(@_);
   bless $self,$class;   
   return $self;
}


sub render
{
   my ($self,$p, $r_handles) = @_;
   my ($ref_loop_info);
   
   $ref_loop_info = $r_handles->{INNER};
   
   if (defined($ref_loop_info) && $ref_loop_info->{ALREADY_DONE}==1)
   {
      return 0;
   }

   # If we have a Y value and it is currently undefined on this page, set it
   if (defined($self->{Y}) && !defined($r_handles->{GLOBALS}->{Y}) ) { 
#   print "row is setting y\n";
      $r_handles->{GLOBALS}->{Y} = $self->{Y};
   }   
   
   # Render each of the elements / containers
   for my $e (@{$self->{ELEMENTS}})
   {
      if (defined($r_handles->{GLOBALS}->{Y}))
      {
         $e->set_y_base($r_handles->{GLOBALS}->{Y});
      }
      
      # Let the element render         
      $e->render($p,$r_handles);
   }
      
    $r_handles->{GLOBALS}->{Y} -= $self->{H};
   
   0;   
}


########################################################################
package PDF::Template::Container::Always;
########################################################################

use vars qw(@ISA);
@ISA = qw (PDF::Template::Container::Base);


sub new
{
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = $class->SUPER::new(@_);
   bless $self,$class;   
   return $self;
}


sub render
{
   my ($self,$p, $r_handles) = @_;
   my ($ref_loop_info);

   my $oldval = $r_handles->{PENDINGBREAK};
   $r_handles->{PENDINGBREAK} = 0;   

   my $old_alreadydone = $r_handles->{ALREADY_DONE};
   $r_handles->{ALREADY_DONE} = 0;
   
   # Render each of the elements / containers
   for my $e (@{$self->{ELEMENTS}})
   {
      # Let the element render         
      $e->render($p,$r_handles);
   }
      
   $r_handles->{PENDINGBREAK} = $oldval;   
   $r_handles->{ALREADY_DONE} = $old_alreadydone;
   
   0;   
}



########################################################################
package PDF::Template::Element::Callback;  # Calls a user defined function
########################################################################





















# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

PDF::Template - Perl extension for separation of data and PDF document layout.

=head1 SYNOPSIS

  use PDF::Template;
  my $rpt = new PDF::Template(FILENAME=>'rpt_allpwps.xml');

  # Set some parameters
  $rpt->param(REPORT_NAME=>'P-9: PWP Booklet');
  $rpt->param(OUTER=>\@arrayofhashrefsofarrayrefsofhashrefsorsomething);

  # Write out a PDF file
  $rpt->write_file('rpt_allpwps.pdf');

=head1 DESCRIPTION

Modules for generating PDF files easily from common data structures.
Separates layout from programming, to some extent.  Like HTML::Template.

Although design is in place for additional providers, currently this
module REQUIRES use of PDFLib (pdflib.com).

=head1 MOTIVATION

I need to create PDF documents for many of the HTML pages I produce.
I immediately adopted a templating tool for my HTML needs; however,
there was no similar tool for PDF.  After a few iterations of my own
tools, I could take it no longer and had to write this.

=head1 Programming Reference

The only object you need be concerned about, programatically, is the
PDF::Template object.

=head2 new()

Produce a new report object.  This can take optional parameters:

=over 4

=item * filename

This is the path to the XML specification for the PDF layout.

=item * openaction

Controls the initial presentation of the PDF when Acrobat 
opens it.  May be set to one of these values: retain, fitpage, 
fitwidth, fitheight, fitbox.  Defaults to 'fitpage'.

=item * openmode

Controls the initial presentation of the PDF when Acrobat 
opens it.  May be set to one of these values:  none, 
bookmarks, thumbnails, fullscreen.  Defaults to 'none'.


=back 4

=head2 param()

param() can be called in a number of ways:

1) To set the value of a parameter :

      # For simple TMPL_VARs:
      $self->param(PARAM => 'value');

      # with a subroutine reference that gets called to get the value
      # of the scalar.  The sub will recieve the template object as a
      # parameter.
      $self->param(PARAM => sub { return 'value' });   

      # And TMPL_LOOPs:
      $self->param(LOOP_PARAM => 
                   [ 
                    { PARAM => VALUE_FOR_FIRST_PASS, ... }, 
                    { PARAM => VALUE_FOR_SECOND_PASS, ... } 
                    ...
                   ]
                  );

2) To set the value of a a number of parameters :

     # For simple TMPL_VARs:
     $self->param(PARAM => 'value', 
                  PARAM2 => 'value'
                 );

      # And with some TMPL_LOOPs:
      $self->param(PARAM => 'value', 
                   PARAM2 => 'value',
                   LOOP_PARAM => 
                   [ 
                    { PARAM => VALUE_FOR_FIRST_PASS, ... }, 
                    { PARAM => VALUE_FOR_SECOND_PASS, ... } 
                    ...
                   ],
                   ANOTHER_LOOP_PARAM => 
                   [ 
                    { PARAM => VALUE_FOR_FIRST_PASS, ... }, 
                    { PARAM => VALUE_FOR_SECOND_PASS, ... } 
                    ...
                   ]
                  );

3) To set the value of a a number of parameters using a hash-ref :

      $self->param(
                   { 
                      PARAM => 'value', 
                      PARAM2 => 'value',
                      LOOP_PARAM => 
                      [ 
                        { PARAM => VALUE_FOR_FIRST_PASS, ... }, 
                        { PARAM => VALUE_FOR_SECOND_PASS, ... } 
                        ...
                      ],
                      ANOTHER_LOOP_PARAM => 
                      [ 
                        { PARAM => VALUE_FOR_FIRST_PASS, ... }, 
                        { PARAM => VALUE_FOR_SECOND_PASS, ... } 
                        ...
                      ]
                    }
                   );



=head2 write_file(filename)

This method writes a PDF file.  "filename" will most likely
need to be a fully qualified path, for example '/home/daf/report.pdf'.

=head2 get_buffer()

Get a buffer containing the PDF.  This is useful if you are going
to stream the PDF directly to a browser:

  my $buf = $rpt->get_buffer();
  print "Content-Type: application/pdf\n";
  print "Content-Length: " . length($buf) . "\n";
  print "Content-Disposition: inline; filename=hello.pdf\n\n";
  print $buf;

=head1 XML Reference

PDF layout is defined in XML.  Programatically, all you need to know is
the few functions discussed above.  The bulk of things to know about using
PDF::Template is the specification of template elements.  This section 
is a reference for those elements.

Example XML code can be found in the examples subdirectory.

All XML objects fall into one of two categories: Containers or Elements.


=head2 A Word on Layout

=head3 Coordinates

A coordinate is a pair (x,y) of numbers representing a point on 
a page.  The 'x' part of the pair represents the distance from
the left edge of the page, while the 'y' component represents 
the distance from the bottom.

Coordinates for PDF::Template are based on an origin of (0,0) in the
lower left corner of the document.  Coordinates are measured in
points, so a position of (72,72) corresponds to a point one inch
from the bottom and one inch from the left of the page.

=head3 Pagination

The challenge in writing a PDF template class, as opposed to an HTML or Text
based template, is pagination.  Simply stated, the pagination problem is that
of determining:

=over 4

=item * What is the Y position of a given element?

=item * Where should a page break occur?

=back 4

Some items, such as those found in headers or footers of reports, are
fixed and should always appear in the same position on each page.

=head2 Containers

There are only a few containers.

=head3 <PAGEDEF>

A pagedef can have the following attributes:

=over 4

=item * pagesize

Indicates the size of the page.  Can be A3 or A4.

=item * landscape

Set this parameter to '1' to swap width and height.  Default is
portrait mode.

=item * nopagenumber

Set this to '1' for these pages not to be counted in the global
page number count.  This could be useful, for example, in a title
page.  Defaults to '0'.  Page numbers are accessible in the 
global '__PAGE__' variable.

=back 4

=head3 <LOOP>

This is the standard looping construct.

Within a loop, several additional variables are available:

=over 4

=item * __FIRST__

=item * __LAST__

=item * __INNER__

=item * __ODD__

=back 4

Loops can have the following attributes:

=over 4

=item * Y

If the current Y position has not yet been set when this loop is
encountered, it will be set to Y.

=item * Y2

The loop will cause a page break when the current Y position exceeds
this value.

=item * MAXITERS

Not implemented.  Will force a page break every N iterations when implemented.

=back 4

=head3 <ROW H='20'>

A row is a container of elements that has a specific height,
specified by the H attribute.  Rows typically exist inside loops.
A row is rendered at the current Y position.  The Y position
is then updated by subtracting the row's height.

=head3 <IF name='' is=''>

This is the construct necessary for conditional inclusion of
elements in the page.

Name is the name of a variable passed in through the param()
function

The 'is' parameter can be either 'true' or 'false'.  If it is
set to 'true', the elements are included if 'name' evaluates to
true.  If set to 'false', the elements are included if name 
evaluates to false.

A more traditional if/else structure is not acheivable in XML.
An if else can be implemented in PDF::Template as:

  <if name='beavis' is='true'>
    ... beavis stuff here ...
  </if>
  <if name='beavis' is='false'>
    ... Hopefully this is never executed
  </if>
  
I considered nesting <true> and <false> tags in the if, but 
I think the notation I chose is simpler for the average case.  

=head3 <ALWAYS>

Use this tag to indicate that the elements in this container
will appear on every page.  This is mose useful when a LOOP 
element in a PAGEDEF causes it to span multiple pages.  In this
case, you could use ALWAYS to make headers and footers appear on 
every page.  Otherwise, items before the LOOP would only appear
on the first page and items after the loop would only appear on
the last page.

=head2 Elements

In general, an element represents a specific item on a PDF.

=head3 Bookmark

 <bookmark name="">Bookmark text, possibly with vars...</bookmark>

Inserts a top level bookmark into the document.  The text of the
bookmark is the text between the two tags.  This text may contain
<var> objects.

PDF supports nested bookmarks.  I have not yet implemented these.

=head3 font

 <font face='Courier' size='12'></font>

Changes the current font.  Size is font size in points (72pts=1 inch).  
Face is the name of the font.  Currently only the PDF core fonts are supported:

=over 4

=item * Courier

=item * Courier-Bold

=item * Courier-Oblique

=item * Courier-BoldOblique

=item * Helvetica

=item * Helvetica-Bold

=item * Helvetica-Oblique

=item * Helvetica-BoldOblique

=item * Times-Roman

=item * Times-Bold

=item * Times-Italic

=item * Times-BoldItalic

=item * Symbol

=item * ZapfDingbats

=back 4

=head3 Image

 <image type='jpeg' scale='' x='' y=''>/file/name/here.jpg</image>
 <image type='gif'><var name='fname'></var></image>

Inserts an image into the document. Type should be one of 
'png','gif','jpeg', or 'tiff'.

The path to the image is between the start and end tags.  It
may contain text and variables.

You may have to play with the scale parameter.  It is passed
directly to PDFLib.

=head3 Line

 <line x1='' y1='' x2='' y2=''></line>

Draws a line from (x1,y1) to (x2,y2).

=head3 Page-Break

 <page-break></page-break>

Inserts a page break.  If you are using it within a loop, consider

 <if name="__LAST__" is="false">
 <page-break></page-break>
 </if>

to avoid an extra page break at the end of the loop.

=head3 TextBox

 <textbox name='' border='' bgcolor='r,g,b' border=0>insert text here</textbox>
 
 <textbox>
   Hello, <var name=username></var>, how are you today?
 </textbox>

Places text on the page.

=over 4

=item * border

Set this to 1 to draw a black border around the text box.  If
omitted, defaults to no border.

=item * bgcolor

The background color for the box can be set with the bgcolor
attribute.  This attribute takes r,g, and b values from 0 to
255.  Unfortunately, it does not look like PDF supports
different foreground colors for text.

=item * X

If an 'X' attribute is specified, it will be used as the X
coordinate for the left hand side of this textbox.  If X is
omitted, the current X position will be used.  Omission of X
may be useful when you want text to immediately follow a 
previous text box.

=item * Y

This is the most (potentially) confusing attribute, as it
may behave one of two ways.

If the TextBox is in a container other than a PageDef, the
Y attribute is treated as an offset from the current Y
position.  In this case, it can be omitted (equivalent to
an offset of 0) or specified, in which case it is subtracted
from the current Y position prior to rendering text.

If the TextBox is in the PageDef container, the Y position
must be specified and is treated as an absolute position.

=item * LMARGIN

If this parameter is used, text drawn in the box is moved
to the right.  This can be used to keep text from touching
the border when border='1' is specified.

=item * RMARGIN

If this parameter is used, the right edge of the text drawn in the box is moved
to the left.  This can be used to keep text from touching
the border when border='1' is specified, especially if text is right
justified.

=back 4

=head3 Pos

 <pos Y='400'></pos>

This is still an experimental element.  Currently it only takes
one parameter, 'Y', which sets the absolute Y position.

I may add X info or relative movement.  Let me know if you
have an opinion.


=head1 AUTHOR

David Ferrance (dave@ferrance.com)


=head1 LICENSE

PDF::Template - Create PDF files from XML Templates.

Copyright (C) 2002 David Ferrance (dave@ferrance.com).  All Rights Reserved. 

This module is free software. It may be used, redistributed and/or modified under the same terms as perl itself. 

=head1 SEE ALSO

perl(1), HTML::Template

=cut