use ExtUtils::MakeMaker;

eval {
    require pdflib_pl;
    die unless $pdflib_pl::VERSION >= 3.0;
};
if ($@) {
    die <<DEATH;

PDF::Template requires the pdflib package from http://www.pdflib.com/ version
3.0 or higher to be installed, and the perl interface "pdflib_pl.pm"
enabled to be able to work properly. Please install that before trying
to install this module.

DEATH
}


# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'PDF::Template',
    'VERSION_FROM' => 'Template.pm', # finds $VERSION
    'PREREQ_PM' => { pdflib_pl => 3.0 },
);
