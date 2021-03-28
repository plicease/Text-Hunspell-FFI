# Text::Hunspell::FFI ![linux](https://github.com/uperl/Text-Hunspell-FFI/workflows/linux/badge.svg) ![macos](https://github.com/uperl/Text-Hunspell-FFI/workflows/macos/badge.svg) ![windows](https://github.com/uperl/Text-Hunspell-FFI/workflows/windows/badge.svg) ![cygwin](https://github.com/uperl/Text-Hunspell-FFI/workflows/cygwin/badge.svg) ![msys2-mingw](https://github.com/uperl/Text-Hunspell-FFI/workflows/msys2-mingw/badge.svg)

Perl FFI interface to the Hunspell library

# SYNOPSIS

```perl
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
```

# DESCRIPTION

**NOTE**: This module is a reimplementation of [Text::Hunspell](https://metacpan.org/pod/Text::Hunspell)
using [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus) instead of `XS`.  The documentation has
largely be cribbed from that module.  The main advantage to this
module is that it does not require a compiler.  The man disadvantage
is that it is experimental and may break.

This module provides a Perl interface to the **Hunspell** library.
This module is to meet the need of looking up many words,
one at a time, in a single session, such as spell-checking
a document in memory.

The example code describes the interface on [http://hunspell.sf.net](http://hunspell.sf.net)

# METHODS

The following methods are available:

## new

```perl
my $spell = Text::Hunspell::FFI->new($full_path_to_affix, $full_path_to_dic);
```

Creates a new speller object. Parameters are:

- full path of affix (.aff) file
- full path of dictionary (.dic) file

Returns `undef` if the object could not be created, which is unlikely.

## add\_dic

```
$spell->add_dic($path_to_dic);
```

Adds a new dictionary to the current `Text::Hunspell::FFI` object. This dictionary
will use the same affix file as the original dictionary, so this is like using
a personal word list in a given language. To check spellings in several
different languages, use multiple `Text::Hunspell::FFI` objects.

## check

```perl
my $bool = $spell->check($word);
```

Check the word. Returns 1 if the word is found, 0 otherwise.

## suggest

```perl
my @words = $spell->suggest($misspelled_word);
```

Returns the list of suggestions for the misspelled word.

The following methods are used for morphological analysis, which is looking
at the structure of words; parts of speech, inflectional suffixes and so on.
However, most of the dictionaries that Hunspell can use are missing this
information and only contain affix flags which allow, for example, 'cat' to
turn into 'cats' but not 'catability'. (Users of the French and Hungarian
dictionaries will find that they have more information available.)

## analyze

```perl
my @words = $spell->analyze($word);
```

Returns the analysis list for the word. This will be a list of
strings that contain a stem word and the morphological information
about the changes that have taken place from the stem. This will
most likely be 'fl:X' strings that indicate that affix flag 'X'
was applied to the stem. Words may have more than one stem, and
each one will be returned as a different item in the list.

However, with a French dictionary loaded, `analyze('chanson')` will return

```
st:chanson po:nom is:fem is:sg
```

to tell you that "chanson" is a feminine singular noun, and
`analyze('chansons')` will return

```
st:chanson po:nom is:fem is:pl
```

to tell you that you've analyzed the plural of the same noun.

## stem

```perl
my @stems = $spell->stem($word);
```

Returns the stem list for the word. This is a simpler version of the
results from `analyze()`.

## generate2

```perl
my @ana = $spell->generate2($stem, \@suggestions)
```

Returns a morphologically modified stem as defined in
`@suggestions` (got by analysis).

With a French dictionary:

```perl
$feminine_form = 'chanteuse';
@ana = $speller->analyze($feminine_form);
$ana[0] =~ s/is:fem/is:mas/;
print $speller->generate2($feminine_form, \@ana)
```

will print 'chanteur'.

## generate

```perl
my @ana = generate($stem, $word)
```

Returns morphologically modified stem like $word.

```perl
$french_speller->generate('danseuse', 'chanteur');
```

tells us that the masculine form of 'danseuse' is 'danseur'.

# SEE ALSO

- [Text::Hunspell](https://metacpan.org/pod/Text::Hunspell)
- [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus)

# CAVEATS

Please see:

- [http://hunspell.sf.net](http://hunspell.sf.net)

For the dictionaries:

- [https://wiki.openoffice.org/wiki/Dictionaries](https://wiki.openoffice.org/wiki/Dictionaries)
- [http://magyarispell.sf.net](http://magyarispell.sf.net) for Hungarian dictionary

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015-2021 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
