package XML::LibXML::AttributeHash;

use strict;
use warnings;
use Tie::Hash;
our @ISA = qw/Tie::Hash/;

use vars qw($VERSION);
$VERSION = "1.90"; # VERSION TEMPLATE: DO NOT CHANGE

sub element {
    return $_[0][0];
}

sub from_clark {
    my ($self, $str) = @_;
    if ($str =~ m! \{ (.+) \} (.+) !x) {
        return ($1, $2);
    }
    return (undef, $str);
}

sub to_clark {
    my ($self, $ns, $local) = @_;
    defined $ns ? "{$ns}$local" : $local;
}

sub all_keys {
    my ($self, @keys) = @_;
    foreach ($self->element->attributes) {
        next if $_->isa('XML::LibXML::Namespace');
        push @keys, $self->to_clark($_->namespaceURI, $_->localname);
    }
    return sort @keys;
}

sub TIEHASH {
    my ($class, $element) = @_;
    bless [$element], $class;
}

sub STORE {
    my ($self, $key, $value) = @_;
    my ($key_ns, $key_local) = $self->from_clark($key);
    if (defined $key_ns) {
        return $self->element->setAttributeNS($key_ns, "xxx:$key_local", "$value");
    }
    else {
        return $self->element->setAttribute($key_local, "$value");
    }
}

sub FETCH {
    my ($self, $key) = @_;
    my ($key_ns, $key_local) = $self->from_clark($key);
    if (defined $key_ns) {
        return $self->element->getAttributeNS($key_ns, "$key_local");
    }
    else {
        return $self->element->getAttribute($key_local);
    }
}

sub EXISTS {
    my ($self, $key) = @_;
    my ($key_ns, $key_local) = $self->from_clark($key);
    if (defined $key_ns) {
        return $self->element->hasAttributeNS($key_ns, "$key_local");
    }
    else {
        return $self->element->hasAttribute($key_local);
    }
}

sub DELETE {
    my ($self, $key) = @_;
    my ($key_ns, $key_local) = $self->from_clark($key);
    if (defined $key_ns) {
        return $self->element->removeAttributeNS($key_ns, "$key_local");
    }
    else {
        return $self->element->removeAttribute($key_local);
    }
}

sub FIRSTKEY {
    my ($self) = @_;
    my @keys = $self->all_keys;
    $self->[1] = \@keys;
    if (wantarray) {
        return ($keys[0], $self->FETCH($keys[0]));
    }
    $keys[0];
}

sub NEXTKEY {
    my ($self, $lastkey) = @_;
    my @keys = defined $self->[1] ? @{ $self->[1] } : $self->all_keys;
    my $found;	
    foreach my $k (@keys) {
        next if $k le $lastkey;
        $found = $k and last;
    }
    if (!defined $found) {
        $self->[1] = undef;
        return;
    }
    if (wantarray) {
        return ($found, $self->FETCH($found));
    }
    return $found;
}

sub SCALAR {
    my ($self) = @_;
    return $self->element;
}

sub CLEAR {
    my ($self) = @_;
    foreach my $k ($self->all_keys) {
        $self->DELETE($k);
    }
    return $self;
}

__PACKAGE__
__END__

=head1 NAME

XML::LibXML::AttributeHash - tie an XML::LibXML::Element to a hash to access its attributes

=head1 SYNOPSIS

 tie my %hash, 'XML::LibXML::AttributeHash', $element;
 $hash{'href'} = 'http://example.com/';
 print $element->getAttribute('href') . "\n";

=head1 DESCRIPTION

This class allows an element's attributes to be accessed as if they were a
plain old Perl hash. Attribute names become hash keys. Namespaced attributes
are keyed using Clark notation.

 my $XLINK = 'http://www.w3.org/1999/xlink';
 tie my %hash, 'XML::LibXML::AttributeHash', $element;
 $hash{"{$XLINK}href"} = 'http://localhost/';
 print $element->getAttributeNS($XLINK, 'href') . "\n";

There is rarely any need to use XML::LibXML::AttributeHash directly. In
general, it is possible to take advantage of XML::LibXML::Element's
overloading. The example in the SYNOPSIS could have been written:

 $element->{'href'} = 'http://example.com/';
 print $element->getAttribute('href') . "\n";

