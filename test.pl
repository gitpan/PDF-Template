# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..7\n"; }
END {print "not ok 1\n" unless $loaded;}
use PDF::Template;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):


my @fnames = qw ( Bert Ernie Kermit Beavis Butthead Cornholio Ren Cartman Kenny Drew );
my @lnames = qw ( Washington Lincoln Bush Hoover Adams Kennedy Eisenhower Garfield Nixon Reagan );


### Test 2

my $rpt = new PDF::Template(FILENAME=>'examples/t2.xml',
                            INFO=>{Creator=>'Dave',Author=>'Tupac Shakur',Title=>"Test T2", Subject=>'Second Subject', Keywords=>'test two keywords pdf template'}
                           );


$rpt->param( { TITLE=>'blah blah',
               SUBTITLE=>'sub blah sub blah',
               B=>'HRDatamine(Tm) THE ESSENTIAL TOOL FOR STRATEGIC ANALYSIS OF HUMAN CAPITAL'
             } 
           );
$rpt->param( DATA=> [ {ORD=>'first'}, {ORD=>'second'}, {ORD=>'third'} ] );

$rpt->write_file("examples/t2.pdf");
print "ok 2\n";


### Test 3 : Loop

my @d3;
my @d3b;
for (my $i=0; $i<20; $i++)
{
   my %h;
   my %h2;
   $h{LNAME} = $lnames[rand(10)];
   $h{FNAME} = $fnames[rand(10)];
   $h{VAL} = $i;
   
   %h2 = %h;
   
   push @d3,\%h;
   push @d3b,\%h2;
}

my $t3 = new PDF::Template(FILENAME=>'examples/t3_loop.xml');
$t3->param(DATA=>\@d3);
$t3->param(DATA2=>\@d3b);

$t3->write_file("examples/t3_loop.pdf");

print "ok 3\n";



### Test 4 : Generic Elements


my $t4 = new PDF::Template(FILENAME=>'examples/t4_elements.xml');

$t4->write_file("examples/t4_elements.pdf");

print "ok 4\n";

### Test 5 : Images


my $t5 = new PDF::Template(FILENAME=>'examples/t5_images.xml');

$t5->write_file("examples/t5.pdf");

print "ok 5\n";

### Test 6 : Conditionals


my $t6 = new PDF::Template(FILENAME=>'examples/t6_conditionals.xml');

my $t6ref = [ { N=>1 }, { N=>2 }, { N=>3 }, { N=>4 }, { N=>5 } ];
$t6->param(DATA=>$t6ref);
$t6->write_file("examples/t6.pdf");

print "ok 6\n";


#### Test 7: Fonts
my $t7 = new PDF::Template(FILENAME=>'examples/t7_fonts.xml');

$t7->write_file("examples/t7.pdf");

print "ok 7\n";
