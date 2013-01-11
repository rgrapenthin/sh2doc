#!/usr/bin/perl
#
##BRIEF
# Script for automatic documentation 
# of shell scripts
#
##AUTHOR
# Ronni Grapenthin
#
##DATE
# 2007-11-20
#
##DETAILS
# 
# This script runs though all directories specified in the field @DIRS and 
# looks at all files whether they contain special documentation makers like:
# <ul>
# <li>##BRIEF</li> 
# <li>##AUTHOR</li>
# <li>##DETAILS</li>
# <li>##DATE</li>
# <li>##CHANGELOG</li>
# </ul>
# If any of these are found, the file is added to an overview contained in an 
# index.html file which lists file name (and a link to a detailed description).
# Furthermore another HTML file is created which contains detailed information
# of the file given in the documentation. Additional meta data of the file such as
# last changed could be added.<br/>
# A line that (starts with spaces only and) contains a comment starting with '#+#' 
# will be added to the details. <p>Empty lines or "##" denote that the subsection
# (e.g. DETAILS) is finished. So use minimal HTML for paragraph formatting and line
# breaks. </p>
#
##CHANGELOG
#
# 2008-01-28 (rn): search for executables, includes non-tagged files / binaries in index.<br>
# 2008-01-29 (rn): sorts filenames, gives separate tables for each letter<br>
# 2009-10-12 (rn): added command line options<br>
#

use File::Copy;
use File::Find;
use File::Basename;
use Getopt::Long;

#CONFIGURATION
########################################################

#Array holding directories whose files are to be parsed (special delimiters in their comment section):
@DIRS;
$INDEX_FILE = "index.html";
$DETAIL_DIR = "details";
@FILES;
$first_letter = "z";
$ALPHABET = "| ";
$LINKS = 0;
$DOCUMENTED = 0;

#CHECK USAGE
if( $#ARGV + 1  < 2)
{
	usage();
	exit();
}

#read in commandline params:
GetOptions (	'in-dir=s'  => \$IN_DIR,   #directory (list, colon separated) containing files to be parsed
		'out-dir=s' => \$OUT_DIR, #path to output directory
		'help' => \$help); #path to output directory

#print help
if ($help) { usage(); exit();}

#check whether output directory exists ...
if (! -d $OUT_DIR) { die("ERROR: Output directory does not exist: '$out_dir'.\n"); }

#add index and detail names to out dir
$INDEX_FILE = "$OUT_DIR/$INDEX_FILE";
$DETAIL_DIR = "$OUT_DIR/$DETAIL_DIR";

#create detail dir, if non-existant
if (! -d $DETAIL_DIR) { mkdir $DETAIL_DIR; }

#compile DIRS that are to be parsed
@DIRS = split /:/, $IN_DIR;

#create indexfile
copy("sh2doc_overview.head", $INDEX_FILE);
#copy("style.css", $OUT_DIR);

#+# fill @FILES with files found in directories given by @DIRS
print "Selecting files from directories: @DIRS\n";
#+# grep all files that are executable and not a directory
find(\&wanted, @DIRS);
#+# sort filenames (depending on first letter of the file, not the full path!)
@FILES = sort filename_sort @FILES;

#+# iterate over all files and check whether they contain tagged comments
foreach $file (@FILES)
{
   print "working on file: $file ... \n";
   create_doc_for($file);
}

#+# read index file and include alphabet selection
open (INDEX, "< $INDEX_FILE") or die "could not open file $INDEX_FILE: $!\n";
while(<INDEX>){
   s/#ALPHABET#/$ALPHABET/;
   $index .= $_
}
close(INDEX);

#+# final writing of index file  ... this is inefficient, optimize, if you can!
open (INDEX, "> $INDEX_FILE") or die "could not open file $INDEX_FILE: $!\n";
print INDEX $index;
open (TAIL, "sh2doc_overview.tail") or die "could not open file sh2doc_overview.tail: $!\n";
@all_tail = <TAIL>;
print INDEX @all_tail;
close(TAIL);
close(INDEX);

$files = @FILES;
$dirs = @DIRS;

print "\n------------------------------------------\n";
print "Documented $DOCUMENTED of $files files in $dirs directories.\n";
print "created symbolic links in $DETAIL_DIR.\n";
print "------------------------------------------\n";

#----------- SUBROUTINES

#compare basenames of files, hence we have to get rid of the path ... uses File::Basename 
sub filename_sort {
   ($fa, $dir, $s) = fileparse($a);
   ($fb, $dir, $s) = fileparse($b);
   
   $fa cmp $fb;
}

# find all executables of a directory which are not directories themselves. append these to the global FILES array.
# however, exclude subdirectories. File::Find::prune = 1 does not work, hence check whether actual directory
# is in the global search array DIRS.
sub wanted {
	if ( grep { $_ eq $File::Find::dir} @DIRS )
	{
		push(@FILES, $File::Find::name) if (-x || -X)  && ! -d;
	}
}

# creates doc for a given file - main routine, but mostly readings
sub create_doc_for ($) {
   local($ff) = @_;
   
   my $doc_found = 0;
   my $author = "";
   my $details = "";
   my $changelog = "";
   my $brief = "";
   my $date = "";
   my $f = $ff;
   my $curpos = 0;

   # we expect the fullpath to be given
   ($f, $dir, $s) = fileparse($ff, '\..*');
   
   open (TODOC, $dir."/".$f.$s) or die "could not open file $ff: $!\n";
   open (INDEX, ">>$INDEX_FILE") or die "could not open file $INDEX_FILE: $!\n";

   while (<TODOC>)
   {
      $curpos = tell TODOC;
      if(/^##BRIEF/){        $brief     .= get_details($ff, $curpos); $doc_found = 1; } 
      elsif(/^##AUTHOR/){    $author    .= get_details($ff, $curpos); $doc_found = 1; }
      elsif(/^##CHANGELOG/){ $changelog .= get_details($ff, $curpos); $doc_found = 1; }
      elsif(/^##DETAILS/){   $details   .= get_details($ff, $curpos); $doc_found = 1; }
      elsif(/^##DATE/){      $date      .= get_details($ff, $curpos); $doc_found = 1; }
      elsif(/^(\s*)(#\+#)(?!#)/)
                           { s/#\+#//; 
		             $details   .= "$_"; $doc_found = 1; }
   }

   #if there is special documentation ... add it to the files
   if($doc_found)
   {
      ++$DOCUMENTED;
      # create symbolic link to source
      symlink("$ff", "$DETAIL_DIR/$f$s") or print "could not create link to $ff: $!\n";
 
      #check whether new table is to be opened
      my @chars = split(//, $f);
      if( @chars[0] ne $first_letter)
      {
   	   $first_letter = @chars[0];
           # add to the index file
           print INDEX "</table>\n<a name=\"$first_letter\"></a><h2>$first_letter</h2>\n \
	   	     <table border=\"1\"> \n\
	   	     <tr><td>script</td><td>directory</td><td>short description</td>\n";
	   	     
   	   $ALPHABET .= " <a href=\"#$first_letter\">$first_letter</a> |";
      }
      
      # add to the index file
      print INDEX " <tr><td> <a href=\"$DETAIL_DIR/$f$s\">$f$s</a> </td>\
                    <td> $dir   </td>\
                    <td> $brief <a href=\"$DETAIL_DIR/$f$s.html\">(more)</a> </td>\n";
      
      # open temp file, create details file
      open (TEMP, "sh2doc_detail.template");
      open (DETAILS, ">$DETAIL_DIR/$f$s.html") or die "could not open file $f$s.html: $!\n";
      
      while(<TEMP>)
      {
   	s/#AUTHOR#/$author/;
 	s/#CHANGELOG#/$changelog/;
	s/#DETAILS#/$details/;
        s/#BRIEF#/$brief/;
        s/#FILENAME#/$f/;
        s/#DATE#/$date/;
        s/#SOURCE#/$f/;
        print DETAILS $_;
      }
      
       
      close(DETAILS); 
      close(TEMP);
   }
#   else
#   {
#     $details = (-B $ff ? "Is binary." : "No tagged comments.");
#
#      # add to the index file ... labeled as not documented
#      print INDEX " <tr><td> <a href=\"$DETAIL_DIR/$f$s\">$f$s</a> </td>\
#                    <td> $dir   </td>\
#                    <td> $details </td>\n";
#   }

   close(INDEX);
   close(TODOC);

}

sub get_details($$)
{
   local ($f, $pos) = @_;
   open (FF, $f) or die "could not open file $f: $!\n";
   seek FF,$pos,0;
   $ret ="";

   while(<FF>)
   {
      last if (!/^#/);
      last if (/^##/);

      s/#//g;
      
      if (/[A-Za-z0-9]/)
      {
         $ret .= $_ . "\n";
      }
  }
  close(FF);
  return $ret;    
}

sub usage() 
{
   #do the printing
   print "$0 Ronni Grapenthin 12 October 2009 \n";
   print "http://www.gps.alaska.edu/ronni/tools/sh2doc.html \n";
   print "Copyright (C) 2007 through 2009, Ronni Grapenthin \n";
   print "$0 comes with ABSOLUTELY NO WARRANTY \n";
   print "This is free software licensed under the Gnu General Public License version 3 \n\n";
   print "Usage: $0 [options] \n\n";
   print "Options: \n";
   print "   --in-dir     Directory to be parsed. A list can be given.\n";
   print "                Separate multiple directories using ':' .\n";
   print "   --out-dir    Output directory. The created documentation will be saved there.\n";
   print "   --help       This help.\n\n";
   print "Example: \n";
   print "   sh2doc.pl --in-dir=.:/etc:/usr/local/bin --out-dir=. \n\n";
   print "   Parses current directory, /etc, and /usr/local/bin and writes results to\n";
   print "   current directory (creates index.html and 'details' directory in '.' \n\n";
}
