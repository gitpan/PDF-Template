# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..4\n"; }
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

my $rpt = new PDF::Template(FILENAME=>'examples/t2.xml');


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
for (my $i=0; $i<100; $i++)
{
   my %h;
   $h{LNAME} = $lnames[rand(10)];
   $h{FNAME} = $fnames[rand(10)];
   $h{VAL} = $i;
   push @d3,\%h;
}

my $t3 = new PDF::Template(FILENAME=>'examples/t3_loop.xml');
$t3->param(DATA=>\@d3);

$t3->write_file("examples/t3_loop.pdf");

print "ok 3\n";



### Test 4 : Generic Elements


my $t4 = new PDF::Template(FILENAME=>'examples/t4_elements.xml');

$t4->write_file("examples/t4_elements.pdf");

print "ok 4\n";
