#!/usr/bin/perl -w

use strict;

use XML::LibXML;
use IO::File;

# ------------------------------------------------------------------------- #
# (c) 2003 christian p. glahn
# ------------------------------------------------------------------------- #

# ------------------------------------------------------------------------- #
# This is an example how to use the DOM interface of XML::LibXML The
# script reads a XML File with a module specification. If the module
# contains several classes, the script fetches them and stores the
# data into different POD Files.
#
# Note this is just an example, to demonstrate how XML::LibXML works.
# The code works for the XML::LibXML documentation, but may not work
# for any other docbook file.
#
# If you are interested what the results are, check the README and the POD
# files shipped with XML::LibXML.
# ------------------------------------------------------------------------- #

# ------------------------------------------------------------------------- #
# SYNOPSIS:
# xmllibxmldocs.pl $dokbook_file $targetdir
#
my $srcfile   = shift @ARGV;
my $targetdir = shift @ARGV;

unless ( $targetdir =~ /\/$/ ) {
    $targetdir .= "/";
}

# ------------------------------------------------------------------------- #
#
# ------------------------------------------------------------------------- #
# init the parser
my $parser = XML::LibXML->new();
$parser->load_ext_dtd(0);
$parser->keep_blanks(0);
# ------------------------------------------------------------------------- #
#
# ------------------------------------------------------------------------- #
# load the document into memory.
my $doc = $parser->parse_file( $srcfile );
# ------------------------------------------------------------------------- #
#
# ------------------------------------------------------------------------- #
# good implementations would use XSLT to convert a docbook to any other
# text format. Since the module does not presume libxslt installed, we
# have to do the dirty job.
my $ch = ChapterHandler->new($targetdir);

# ------------------------------------------------------------------------- #
# init the common parts in all pods
my ( $bookinfo ) = $doc->findnodes( "//bookinfo" );
$ch->set_general_info( $bookinfo );
# ------------------------------------------------------------------------- #

# ------------------------------------------------------------------------- #
# then process each chapter of the XML::LibXML book
my @chapters = $doc->findnodes( "//chapter" );
foreach my $chap ( @chapters ) {
    $ch->handle( $chap );
}
# ------------------------------------------------------------------------- #
# ------------------------------------------------------------------------- #

# ------------------------------------------------------------------------- #
# the class to process our dokbook file
# ------------------------------------------------------------------------- #
package ChapterHandler;
use XML::LibXML;

# ------------------------------------------------------------------------- #
# the constructor
# ------------------------------------------------------------------------- #
sub new{
    my $class = shift;
    my $dir   = shift;
    my $self = bless {directory => $dir}, $class;

    return $self;
}
# ------------------------------------------------------------------------- #

# ------------------------------------------------------------------------- #
# set_general_info
# ------------------------------------------------------------------------- #
# processes the bookinfo tag of XML::LibXML to extract common information such
# as version or copyright information
sub set_general_info {
    my $self = shift;
    my $infonode = shift;
    return unless defined $infonode;

    my $infostr = "=head1 AUTHORS\n\n";
    my @authors = $infonode->findnodes( "authorgroup/author" );
    foreach my $author ( @authors ) {
        my ( $node_fn ) = $author->getChildrenByTagName( "firstname" );
        my ( $node_sn ) = $author->getChildrenByTagName( "surname" );
        if ( defined $node_fn ) {
            $infostr .= $node_fn->string_value();
        }
        if ( defined $node_sn ) {
            $infostr .= " ". $node_sn->string_value();
        }
        if ( defined $author->nextSibling() ) {
            $infostr .= ", \n";
        }
        else {
            $infostr .= "\n\n";
        }
    }

    my ( $version ) = $infonode->findnodes( "edition" );
    if ( defined $version ) {
        $infostr .= "\n=head1 VERSION\n\n" . $version->string_value() . "\n\n";
    }

    my @copyright = $infonode->findnodes( "copyright" );
    if ( @copyright ) {
        $infostr .= "=head1 COPYRIGHT\n\n";
        foreach my $copyright (@copyright) {
          my $node_y = $copyright->getChildrenByTagName( "year" );
          my $node_h = $copyright->getChildrenByTagName( "holder" );
          if ( defined $node_y ) {
            $infostr .= $node_y->string_value() . ", ";
          }
          if ( defined $node_h ) {
            $infostr .= $node_h->string_value();
          }
          $infostr .= ".\n\n";
        }
        $infostr .= "=cut\n";

        $infostr .= "\n\n".<<'EOF';
=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

EOF
    }

    $self->{infoblock} = $infostr;
}

# ------------------------------------------------------------------------- #
# handle
# ------------------------------------------------------------------------- #
# This function opens the output file and decides how the chapter is
# processed
sub handle {
    my $self = shift;
    my $chapter = shift;

    my ( $abbr ) = $chapter->findnodes( "titleabbrev" );
    if ( defined $abbr ) {
        # create a new file.
        my $filename = $abbr->string_value();
        $filename =~ s/^\s*|\s*$//g;
        my $dir = $self->{directory};

        $filename =~ s/XML\:\:LibXML//g;
        $filename =~ s/^-|^\:\://g;   # remove the first colon or minus.
        $filename =~ s/\:\:/\//g;     # transform remaining colons to paths.
        # the previous statement should work for existing modules. This could be
        # dangerous for nested modules, which do not exist at the time of writing
        # this code.

        unless ( length $filename ) {
            $dir = "";
            $filename = "LibXML";
        }

        if ( $filename ne "README" and $filename ne "LICENSE" ) {
            $filename .= ".pod";
        }
        else {
            $dir = "";
        }

        $self->{OFILE} = IO::File->new();
        $self->{OFILE}->open(">".$dir.$filename);

        if ( $abbr->string_value() eq "README"
             or $abbr->string_value() eq "LICENSE" ) {

            # Text only chapters in the documentation
            $self->dump_text( $chapter );
        }
        else {
            # print header
            # print synopsis
            # process the information itself
            # dump the info block
            $self->dump_pod( $chapter );
            $self->{OFILE}->print( $self->{infoblock} );
        }
        # close the file
        $self->{OFILE}->close();

        # Strip trailing space.
        my $text = _slurp($dir.$filename);
        $text =~ s/[ \t]+$//gms;

        open my $out, '>', $dir.$filename
            or die "Cannot open $dir$filename for writing.";
        print {$out} $text;
        close ($out);

    }
}

sub _slurp
{
    my $filename = shift;

    open my $in, '<', $filename
        or die "Cannot open '$filename' for slurping - $!";

    local $/;
    my $contents = <$in>;

    close($in);

    return $contents;
}

# ------------------------------------------------------------------------- #
# dump_text
# ------------------------------------------------------------------------- #
# convert the chapter into a textfile, such as README.
sub dump_text {
    my $self = shift;
    my $chap = shift;

    if ( $chap->nodeName() eq "chapter" ) {
        my ( $title ) = $chap->getChildrenByTagName( "title" );
        my $str =  $title->string_value();
        my $len = length $str;
        $self->{OFILE}->print( uc($str) . "\n" );
        $self->{OFILE}->print( "=" x $len );
        $self->{OFILE}->print( "\n\n" );
    }

    foreach my $node ( $chap->childNodes() ) {
        if ( $node->nodeName() eq "para" ) {
            # we split at the last whitespace before 80 chars
            my $string = $node->string_value();
            my $os = "";
            my @words = split /\s+/, $string;
            foreach my $word ( @words ) {
                if ( (length( $os ) + length( $word ) + 1) < 80 ) {
                    if ( length $os ) { $os .= " "; }
                    $os .= $word;
                }
                else {
                    $self->{OFILE}->print( $os . "\n" );
                    $os = $word;
                }
            }
            $self->{OFILE}->print( $os );
            $self->{OFILE}->print( "\n\n" );
        }
        elsif ( $node->nodeName() eq "sect1" ) {
            my ( $title ) = $node->getChildrenByTagName( "title" );
            my $str = $title->string_value();
            my $len = length $str;

            $self->{OFILE}->print( "\n" . uc($str) . "\n" );
            $self->{OFILE}->print( "=" x $len );
            $self->{OFILE}->print( "\n\n" );
            $self->dump_text( $node );
        }
        elsif (  $node->nodeName() eq "sect2" ) {
            my ( $title ) = $node->getChildrenByTagName( "title" );
            my $str = $title->string_value();
            my $len = length $str;

            $self->{OFILE}->print( "\n" . $str . "\n" );
            $self->{OFILE}->print( "=" x $len );
            $self->{OFILE}->print( "\n\n" );
            $self->dump_text( $node );
        }
        elsif ( $node->nodeName() eq "itemizedlist" ) {
            my @items = $node->findnodes( "listitem" );
            my $sp= "  ";
            foreach my $item ( @items ) {
                $self->{OFILE}->print( "$sp o " );
                my $str = $item->string_value();
                $str =~ s/^\s*|\s*$//g;
                $self->{OFILE}->print( $str );
                $self->{OFILE}->print( "\n" );
            }
            $self->{OFILE}->print( "\n" );
        }
        elsif ( $node->nodeName() eq "orderedlist" ) {
            my @items = $node->findnodes( "listitem" );
            my $i = 0;
            my $sp= "  ";
            foreach my $item ( @items ) {
                $i++;
                $self->{OFILE}->print( "$sp $i " );
                my $str = $item->string_value();
                $str =~ s/^\s*|\s*$//g;
                $self->{OFILE}->print( $str );
                $self->{OFILE}->print( "\n" );
            }
            $self->{OFILE}->print( "\n" );
        }
        elsif ( $node->nodeName() eq "programlisting" ) {
            my $str = $node->string_value();
            $str =~ s/\n/\n> /g;
            $self->{OFILE}->print( "> ". $str );
            $self->{OFILE}->print( "\n\n" );
        }
    }
}

# ------------------------------------------------------------------------- #
# dump_pod
# ------------------------------------------------------------------------- #
# This method is used to create the real POD files for XML::LibXML. It is not
# too sophisticated, but it already does quite a good job.
sub dump_pod {
    my $self = shift;
    my $chap = shift;

    if ( $chap->nodeName() eq "chapter" ) {
        my ( $title ) = $chap->getChildrenByTagName( "title" );
        my ( $ttlabbr ) = $chap->getChildrenByTagName( "titleabbrev" );
        my $str =  $ttlabbr->string_value() . " - ".$title->string_value();
        $str=~s/^\s+|\s+$//g;
        $self->{OFILE}->print(  "=head1 NAME\n\n$str\n" );
        my ($synopsis) = $chap->findnodes( "sect1[title='Synopsis']" );
        my @funcs = $chap->findnodes( ".//funcsynopsis" );
        if ($synopsis or scalar @funcs) {
            $self->{OFILE}->print( "\n=head1 SYNOPSIS\n\n" )
        }
        if ($synopsis) {
          $self->dump_pod( $synopsis );
        }
        if ( scalar @funcs ) {
            foreach my $s ( @funcs ) {
                $self->dump_pod( $s );
            }
            # $self->{OFILE}->print( "\n\n=head1 DESCRIPTION\n\n" );
        }
    }

    foreach my $node ( $chap->childNodes() ) {
      if ( $node->nodeType == XML_TEXT_NODE ||
             $node->nodeType == XML_CDATA_SECTION_NODE ) {
        # we split at the last whitespace before 80 chars
        my $prev_inline =
          ($node->previousSibling and
           $node->previousSibling->nodeName !~
             /^(?:itemizedlist|orderedlist|variablelist|programlisting|funcsynopsis)/)
            ? 1 : 0;
        my $str = $node->data();
        $str=~s/(^|\n)[ \t]+($|\n)/$1$2/g;
        if ($str=~/\S/) {
          my $string = $str;
          my $space_before = ($string =~ s/^\s+//g) ? $prev_inline : 0;
          my $space_after = ($string =~ s/\s+$//g) ? 1 : 0;
          $self->{OFILE}->print( " " ) if $space_before;
          my $os = "";
          my @words = split /\s+/, $string;
          foreach my $word ( @words ) {
            if ( (length( $os ) + length( $word ) + 1) < 80 ) {
              if ( length $os ) { $os .= " "; }
            $os .= $word;
            }
            else {
              $self->{OFILE}->print( $os . "\n" );
              $os = $word;
            }
          }
          $os.=" " if $space_after;
          $self->{OFILE}->print( $os );
        }
      } elsif ( $node->nodeName() eq "para" ) {
        $self->dump_pod( $node );
        $self->{OFILE}->print( "\n\n" );
      } elsif ( $node->nodeName() eq "sect1" ) {
            my ( $title ) = $node->getChildrenByTagName( "title" );
            my $str = $title->string_value();
            unless ($chap->nodeName eq "chapter" and $str eq 'Synopsis') {
              $self->{OFILE}->print( "\n=head1 " . uc($str) );
              $self->{OFILE}->print( "\n\n" );
              $self->dump_pod( $node );
            }
        }
        elsif (  $node->nodeName() eq "sect2" ) {
            my ( $title ) = $node->getChildrenByTagName( "title" );
            my $str = $title->string_value();
            my $len = length $str;

            $self->{OFILE}->print( "\n=head2 " . $str . "\n\n" );

            $self->dump_pod( $node );
        }
        elsif (  $node->nodeName() eq "sect3" ) {
            my ( $title ) = $node->getChildrenByTagName( "title" );
            my $str = $title->string_value();
            my $len = length $str;

            $self->{OFILE}->print( "\n=head3 " . $str . "\n\n" );

            $self->dump_pod( $node );
        }
        elsif ( $node->nodeName() eq "itemizedlist" ) {
            my @items = $node->findnodes( "listitem" );
            $self->{OFILE}->print( "\n=over 4\n\n" );
            foreach my $item ( @items ) {
                $self->{OFILE}->print( "=item *\n\n" );
                $self->dump_pod( $item );
                $self->{OFILE}->print( "\n\n" );
            }
            $self->{OFILE}->print( "=back\n\n" );
        }
        elsif ( $node->nodeName() eq "orderedlist" ) {
            my @items = $node->findnodes( "listitem" );
            my $i = 0;
            $self->{OFILE}->print( "\n=over 4\n\n" );

            foreach my $item ( @items ) {
                $i++;
                $self->{OFILE}->print( "=item $i.\n\n" );
                $self->dump_pod($item);
                $self->{OFILE}->print( "\n\n" );
            }
            $self->{OFILE}->print( "=back\n\n" );
        }
        elsif ( $node->nodeName() eq "variablelist" ) {
            $self->{OFILE}->print( "=over 4\n\n" );
            my @nodes = $node->findnodes( "varlistentry" );
            $self->dump_pod( $node );
            $self->{OFILE}->print( "\n=back\n\n" );
        }
        elsif ( $node->nodeName() eq "varlistentry" ) {
            my ( $term ) = $node->findnodes( "term" );
            $self->{OFILE}->print( "=item " );
            if ( defined $term ) {
              $self->dump_pod( $term );
            }
            $self->{OFILE}->print( "\n\n" );
            my @nodes =$node->findnodes( "listitem" );
            foreach my $it ( @nodes ) {
                $self->dump_pod( $it );
            }
            $self->{OFILE}->print( "\n" );
        }
        elsif ( $node->nodeName() eq "programlisting" ) {
            my $str = $node->string_value();
            $str =~ s/^\s+|\s+$//g;
            $str =~ s/\n/\n  /g;
            $str=~s/(^|\n)[ \t]+($|\n)/$1$2/g;
            $self->{OFILE}->print( "\n\n" );
            $self->{OFILE}->print( "  ". $str );
            $self->{OFILE}->print( "\n\n" );
        }
        elsif ( $node->nodeName() eq "funcsynopsis") {
            if (($node->getAttribute('role')||'') ne 'synopsis') {
              $self->dump_pod($node);
              $self->{OFILE}->print( "\n" );
            }
        }
        elsif(  $node->nodeName() eq "funcsynopsisinfo" ) {
            my $str = $node->string_value() ;
            $str =~ s/\n/\n  /g;
            $self->{OFILE}->print( "  $str\n" );
        } elsif(  $node->nodeName() eq "title" or
                  $node->nodeName() eq "titleabbrev"
                 ) {
          # IGNORE
        } elsif(  $node->nodeName() eq "emphasis" ) {
            my $str = $node->string_value() ;
            $str =~ s/\n/ /g;
            $self->{OFILE}->print( "I<<<<<< $str >>>>>>" );
        } elsif(  $node->nodeName() eq "function" or
                  $node->nodeName() eq "email" or
                  $node->nodeName() eq "literal"
               ) {
            my $str = $node->string_value() ;
            $str =~ s/\n/ /g;
            $self->{OFILE}->print( "C<<<<<< $str >>>>>>" );
        } elsif(  $node->nodeName() eq "ulink" ) {
            my $str = $node->string_value() ;
            my $url = $node->getAttribute('url');
            $str =~ s/\n/ /g;
            if ($str eq $url) {
              $self->{OFILE}->print( "L<<<<<< $url >>>>>>" );
            } else {
              $self->{OFILE}->print( "$str (L<<<<<< $url >>>>>>)" );
            }
        } elsif(  $node->nodeName() eq "xref" ) {
            my $linkend = $node->getAttribute('linkend');
            my ($target) = $node->findnodes(qq(//*[\@id="$linkend"]/titleabbrev));
            ($target) = $node->findnodes(qq(//*[\@id="$linkend"]/title)) unless $target;
            if ($target) {
              my $str = $target->string_value() ;
              $str =~ s/\n/ /g;
              $self->{OFILE}->print( "L<<<<<< $str >>>>>>" );
            } else {
              warn "WARNING: Didn't find any section with id='$linkend'\n";
              $self->{OFILE}->print( "$linkend" );
            }
        } elsif(  $node->nodeName() eq "olink" ) {
            my $str = $node->string_value() ;
            my $url = $node->getAttribute('targetdoc');
            if (!defined $url) {
              warn $node->toString(1),"\n";
            }
            $str =~ s/\n/ /g;
            if ($str eq $url) {
              $self->{OFILE}->print( "L<<<<<< $url >>>>>>" );
            } else {
              $self->{OFILE}->print( "$str (L<<<<<< $url >>>>>>)" );
            }
        } else {
          print STDERR "Ignoring ",$node->nodeName(),"\n";
          $self->dump_pod($node);
        }
    }
}

1;
