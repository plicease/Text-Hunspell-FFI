package Text::Hunspell::FFI;

use strict;
use warnings;
use 5.020;
use FFI::Platypus 1.00;
use FFI::CheckLib 0.27 ();
use experimental qw( postderef );

# ABSTRACT: Perl FFI interface to the Hunspell library
# VERSION

sub _lib
{
  my @args = (lib => '*', verify => sub { $_[0] =~ /hunspell/ }, symbol => "Hunspell_create");
  my @libs = FFI::CheckLib::find_lib @args;
  my($first) = @libs
    ? @libs
    : FFI::CheckLib::find_lib @args, alien => 'Alien::Hunspell';
  die "unable to find libs" unless $first;
  $first;
}

my $ffi = FFI::Platypus->new(
  api => 1,
  lib => _lib(),
);

$ffi->attach(['Hunspell_create'=>'new'] => ['string','string'] => 'opaque', sub
{
  my($xsub, $class, $aff, $dic) = @_;
  my $ptr = $xsub->($aff, $dic);
  bless \$ptr, $class;
});


$ffi->attach(['Hunspell_destroy'=>'DESTROY'] => ['opaque'] => 'void', sub
{
  my($xsub, $self) = @_;
  $xsub->($$self);
});

foreach my $try (qw( Hunspell_add_dic _ZN8Hunspell7add_dicEPKcS1_ ))
{
  eval {
    $ffi->attach([$try=>'add_dic'] => ['opaque','string'] => 'void', sub
    {
      my($xsub, $self, $dpath) = @_;
      $xsub->($$self, $dpath);
    });
  };
  last unless $@;
}

unless(__PACKAGE__->can('add_dic'))
{
  # TODO: fallback on Perl implementation ?
  die "unable to find add_dic";
}

$ffi->attach(['Hunspell_spell'=>'check'] => ['opaque','string'] => 'int', sub
{
  my($xsub, $self, $word) = @_;
  $xsub->($$self, $word);
});

$ffi->attach(['Hunspell_free_list',=>'_free_list'] => ['opaque','opaque*','int'] => 'void');

sub _string_array_and_word
{
  my($xsub, $self, $word) = @_;
  my $ptr;
  my $count = $xsub->($$self, \$ptr, $word);
  my @result = defined $ptr ? map { $ffi->cast('opaque','string',$_) } $ffi->cast('opaque',"opaque[$count]", $ptr)->@* : ();
  _free_list($self, $ptr, $count) if defined $ptr;
  wantarray ? @result : $result[0];  ## no critic (Freenode::Wantarray)
}

$ffi->attach(['Hunspell_suggest'=>'suggest'] => ['opaque','opaque*','string'] => 'int', \&_string_array_and_word);
$ffi->attach(['Hunspell_analyze'=>'analyze'] => ['opaque','opaque*','string'] => 'int', \&_string_array_and_word);

$ffi->attach(['Hunspell_generate'=>'generate'] => ['opaque','opaque*','string','string'] => 'int', sub {
  my($xsub, $self, $word, $word2) = @_;
  my $ptr;
  my $count = $xsub->($$self, \$ptr, $word, $word2);
  my @result = defined $ptr ? map { $ffi->cast('opaque','string',$_) } $ffi->cast('opaque',"opaque[$count]", $ptr)->@* : ();
  _free_list($self, $ptr, $count) if $ptr;
  wantarray ? @result : $result[0];  ## no critic (Freenode::Wantarray)
});

$ffi->attach(['Hunspell_generate2'=>'generate2'] => ['opaque','opaque*','string','string[]','int'] => 'int', sub
{
  my($xsub, $self, $word, $suggestions) = @_;
  my $n = scalar @$suggestions;
  my $ptr;
  my $count = $xsub->($$self, \$ptr, $word, [@$suggestions], 1);
  my @result = defined $ptr ? map { $ffi->cast('opaque','string',$_) } $ffi->cast('opaque',"opaque[$count]", $ptr)->@* : ();
  _free_list($self, $ptr, $count) if defined $ptr;
  wantarray ? @result : $result[0];  ## no critic (Freenode::Wantarray)
});

1;

__END__

=encoding utf8

=head1 SYNOPSIS

    use Text::Hunspell::FFI;
 
    # You can use relative or absolute paths.
    my $speller = Text::Hunspell::FFI->new(
        "/usr/share/hunspell/en_US.aff",    # Hunspell affix file
        "/usr/share/hunspell/en_US.dic"     # Hunspell dictionary file
    );
 
    die unless $speller;
 
    # Check a word against the dictionary
    my $word = 'opera';
    print $speller->check($word)
          ? "'$word' found in the dictionary\n"
          : "'$word' not found in the dictionary!\n";
 
    # Spell check suggestions
    my $misspelled = 'programmng';
    my @suggestions = $speller->suggest($misspelled);
    print "\n", "You typed '$misspelled'. Did you mean?\n";
    for (@suggestions) {
        print "  - $_\n";
    }
 
    # Add dictionaries later
    $speller->add_dic('dictionary_file.dic');


=head1 DESCRIPTION

B<NOTE>: This module is a reimplementation of L<Text::Hunspell>
using L<FFI::Platypus> instead of C<XS>.  The documentation has
largely be cribbed from that module.  The main advantage to this
module is that it does not require a compiler.  The man disadvantage
is that it is experimental and may break.

This module provides a Perl interface to the B<Hunspell> library.
This module is to meet the need of looking up many words,
one at a time, in a single session, such as spell-checking
a document in memory.

The example code describes the interface on L<http://hunspell.sf.net>

=head1 METHODS

The following methods are available:

=head2 new

 my $spell = Text::Hunspell::FFI->new($full_path_to_affix, $full_path_to_dic);

Creates a new speller object. Parameters are:

=over 4

=item full path of affix (.aff) file

=item full path of dictionary (.dic) file

=back

Returns C<undef> if the object could not be created, which is unlikely.

=head2 add_dic

 $spell->add_dic($path_to_dic);

Adds a new dictionary to the current C<Text::Hunspell::FFI> object. This dictionary
will use the same affix file as the original dictionary, so this is like using
a personal word list in a given language. To check spellings in several
different languages, use multiple C<Text::Hunspell::FFI> objects.

=head2 check

 my $bool = $spell->check($word);

Check the word. Returns 1 if the word is found, 0 otherwise.

=head2 suggest

 my @words = $spell->suggest($misspelled_word);

Returns the list of suggestions for the misspelled word.

The following methods are used for morphological analysis, which is looking
at the structure of words; parts of speech, inflectional suffixes and so on.
However, most of the dictionaries that Hunspell can use are missing this
information and only contain affix flags which allow, for example, 'cat' to
turn into 'cats' but not 'catability'. (Users of the French and Hungarian
dictionaries will find that they have more information available.)

=head2 analyze

 my @words = $spell->analyze($word);

Returns the analysis list for the word. This will be a list of
strings that contain a stem word and the morphological information
about the changes that have taken place from the stem. This will
most likely be 'fl:X' strings that indicate that affix flag 'X'
was applied to the stem. Words may have more than one stem, and
each one will be returned as a different item in the list.

However, with a French dictionary loaded, C<analyze('chanson')> will return

  st:chanson po:nom is:fem is:sg

to tell you that "chanson" is a feminine singular noun, and
C<analyze('chansons')> will return

  st:chanson po:nom is:fem is:pl

to tell you that you've analyzed the plural of the same noun.

=head2 stem

 my @stems = $spell->stem($word);

Returns the stem list for the word. This is a simpler version of the
results from C<analyze()>.

=head2 generate2

 my @ana = $spell->generate2($stem, \@suggestions)

Returns a morphologically modified stem as defined in
C<@suggestions> (got by analysis).

With a French dictionary:

  $feminine_form = 'chanteuse';
  @ana = $speller->analyze($feminine_form);
  $ana[0] =~ s/is:fem/is:mas/;
  print $speller->generate2($feminine_form, \@ana)

will print 'chanteur'.

=head2 generate

 my @ana = generate($stem, $word)

Returns morphologically modified stem like $word.

  $french_speller->generate('danseuse', 'chanteur');

tells us that the masculine form of 'danseuse' is 'danseur'.

=head1 SEE ALSO

=over 4

=item L<Text::Hunspell>

=item L<FFI::Platypus>

=back

=head1 CAVEATS

Please see:

=over 4

=item L<http://hunspell.sf.net>

=back

For the dictionaries:

=over 4

=item L<https://wiki.openoffice.org/wiki/Dictionaries>

=item L<http://magyarispell.sf.net> for Hungarian dictionary

=back

=cut
