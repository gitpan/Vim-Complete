package Vim::Complete;

use strict;
use warnings;
use PPI;
use File::Find;
use File::Spec;


our $VERSION = '0.03';


use base qw(Class::Accessor::Complex);


__PACKAGE__
    ->mk_new
    ->mk_scalar_accessors(qw(min_length))
    ->mk_array_accessors(qw(dirs))
    ->mk_hash_accessors(qw(result))
    ->mk_boolean_accessors(qw(verbose));


sub gather {
    my ($self, $filename) = @_;

    # does PPI not like relative filenames?
    $filename = File::Spec->rel2abs($filename);

    my $document = PPI::Document->new($filename);

    unless (UNIVERSAL::isa($document, 'PPI::Document')) {
        warn "couldn't parse $filename\n";
        return;
    }

    # get a hash reference so we can change the hash in place
    my $result = $self->result;

    my $min_length = $self->min_length || 3;

    $result->{$_} = 1 for
        grep { /\w{$min_length,}/ }
        map  { $_->namespace }
        @{ $document->find('PPI::Statement::Package') || [] };

    $result->{$_} = 1 for
        grep { /\w{$min_length,}/ }
        map  { substr($_, 0, 1, ''); $_ }
        map  { $_->variables }
        @{ $document->find('PPI::Statement::Variable') || [] };

    $result->{$_} = 1 for
        grep { /\w{$min_length,}/ }
        map  { $_->name }
        @{ $document->find('PPI::Statement::Sub') || [] };
}


sub report {
    my $self = shift;
    my @result = sort $self->result_keys;
    wantarray ? @result : \@result;
}

sub report_to_file {
    my ($self, $filename) = @_;
    die "no filename\n" unless defined $filename;
    open my $fh, '>', $filename or die "can't open $filename for writing: $!\n";
    print $fh "$_\n" for $self->report;
    close $fh or die "can't close $fh: $!\n";
}


sub parse {
    my $self = shift;
    my $verbose = $self->verbose;
    find(sub {
        return unless -f && /\.pm$/;

        # We can see a file more than once if we have nested paths in @INC, so
        # check

        our %seen;
        return if $seen{$File::Find::name}++;

        warn "processing $File::Find::name\n" if $verbose;
        $self->gather($_);
    }, $self->dirs);

    $self; # for chaining
}


1;


__END__



=head1 NAME

Vim::Complete - Generate autocompletion information for vim

=head1 SYNOPSIS

    Vim::Complete->new(
        dirs       => \@dirs,
        verbose    => $verbose,
        min_length => $min_length,
    )->parse->report_to_file($filename);

=head1 DESCRIPTION

Vim has a good autocompletion mechanism. In insert mode, you can type
Control-n to complete on the current string; you can cycle through the
possible completions by repeatedly typing Control-n. See C<:help complete> in
vim for more information.

By default, vim completes on identifiers it finds in the current buffer,
buffers in other windows, other loaded buffers, unloaded buffers, tags and
included files. That means you still have to type the identifier once so
vim knows about it.

However, you can extend the way vim completes. It can take additional
identifiers from a file. So Vim::Complete takes a list of directories -
usually C<@INC> -, looks at the modules contained therein, parses package
names, variable names and subroutine names and writes them to a file.

Now you need to tell vim where to find the file with the Perl identifiers. Put
this line into your C<.vimrc>:

    set complete+=k~/.vimcomplete

The <+=k> tells vim to also look into the specified file.

For this to work well, you need to tell vim that colons are part of
identifiers in Perl (for example, C<Foo::Bar> is an identifier. Put this line
in your C<.vimrc>:

    set iskeyword+=:

Included in this distribution is the program C<mk_vim_complete>, which is a
command-line frontend to Vim::Complete.

You can tell Vim::Complete to only use identifiers that are of a certain
minimum length. An identifier that is only one character long (such as C<$x>)
doesn't need to be completed. If you would include two-character identifiers,
you might throw off the autocompletion by having to cycle through too many
identifiers. So the default minimum length is 3.

=head1 METHODS

=over 4

=item new

    my $obj = Vim::Complete->new;
    my $obj = Vim::Complete->new(%args);

Creates and returns a new object. The constructor will accept as arguments a
list of pairs, from component name to initial value. For each pair, the named
component is initialized by calling the method of the same name with the given
value. If called with a single hash reference, it is dereferenced and its
key/value pairs are set as described before.

=item clear_dirs

    $obj->clear_dirs;

Deletes all elements from the array.

=item clear_min_length

    $obj->clear_min_length;

Clears the value.

=item clear_result

    $obj->clear_result;

Deletes all keys and values from the hash.

=item clear_verbose

    $obj->clear_verbose;

Clears the boolean value by setting it to 0.

=item count_dirs

    my $count = $obj->count_dirs;

Returns the number of elements in the array.

=item delete_result

    $obj->delete_result(@keys);

Takes a list of keys and deletes those keys from the hash.

=item dirs

    my @values    = $obj->dirs;
    my $array_ref = $obj->dirs;
    $obj->dirs(@values);
    $obj->dirs($array_ref);

Get or set the array values. If called without an arguments, it returns the
array in list context, or a reference to the array in scalar context. If
called with arguments, it expands array references found therein and sets the
values.

=item dirs_clear

    $obj->dirs_clear;

Deletes all elements from the array.

=item dirs_count

    my $count = $obj->dirs_count;

Returns the number of elements in the array.

=item dirs_index

    my $element   = $obj->dirs_index(3);
    my @elements  = $obj->dirs_index(@indices);
    my $array_ref = $obj->dirs_index(@indices);

Takes a list of indices and returns the elements indicated by those indices.
If only one index is given, the corresponding array element is returned. If
several indices are given, the result is returned as an array in list context
or as an array reference in scalar context.

=item dirs_pop

    my $value = $obj->dirs_pop;

Pops the last element off the array, returning it.

=item dirs_push

    $obj->dirs_push(@values);

Pushes elements onto the end of the array.

=item dirs_set

    $obj->dirs_set(1 => $x, 5 => $y);

Takes a list of index/value pairs and for each pair it sets the array element
at the indicated index to the indicated value. Returns the number of elements
that have been set.

=item dirs_shift

    my $value = $obj->dirs_shift;

Shifts the first element off the array, returning it.

=item dirs_splice

    $obj->dirs_splice(2, 1, $x, $y);
    $obj->dirs_splice(-1);
    $obj->dirs_splice(0, -1);

Takes three arguments: An offset, a length and a list.

Removes the elements designated by the offset and the length from the array,
and replaces them with the elements of the list, if any. In list context,
returns the elements removed from the array. In scalar context, returns the
last element removed, or C<undef> if no elements are removed. The array grows
or shrinks as necessary. If the offset is negative then it starts that far
from the end of the array. If the length is omitted, removes everything from
the offset onward. If the length is negative, removes the elements from the
offset onward except for -length elements at the end of the array. If both the
offset and the length are omitted, removes everything. If the offset is past
the end of the array, it issues a warning, and splices at the end of the
array.

=item dirs_unshift

    $obj->dirs_unshift(@values);

Unshifts elements onto the beginning of the array.

=item exists_result

    if ($obj->exists_result($key)) { ... }

Takes a key and returns a true value if the key exists in the hash, and a
false value otherwise.

=item index_dirs

    my $element   = $obj->index_dirs(3);
    my @elements  = $obj->index_dirs(@indices);
    my $array_ref = $obj->index_dirs(@indices);

Takes a list of indices and returns the elements indicated by those indices.
If only one index is given, the corresponding array element is returned. If
several indices are given, the result is returned as an array in list context
or as an array reference in scalar context.

=item keys_result

    my @keys = $obj->keys_result;

Returns a list of all hash keys in no particular order.

=item min_length

    my $value = $obj->min_length;
    $obj->min_length($value);

A basic getter/setter method. If called without an argument, it returns the
value. If called with a single argument, it sets the value.

=item min_length_clear

    $obj->min_length_clear;

Clears the value.

=item pop_dirs

    my $value = $obj->pop_dirs;

Pops the last element off the array, returning it.

=item push_dirs

    $obj->push_dirs(@values);

Pushes elements onto the end of the array.

=item result

    my %hash     = $obj->result;
    my $hash_ref = $obj->result;
    my $value    = $obj->result($key);
    my @values   = $obj->result([ qw(foo bar) ]);
    $obj->result(%other_hash);
    $obj->result(foo => 23, bar => 42);

Get or set the hash values. If called without arguments, it returns the hash
in list context, or a reference to the hash in scalar context. If called
with a list of key/value pairs, it sets each key to its corresponding value,
then returns the hash as described before.

If called with exactly one key, it returns the corresponding value.

If called with exactly one array reference, it returns an array whose elements
are the values corresponding to the keys in the argument array, in the same
order. The resulting list is returned as an array in list context, or a
reference to the array in scalar context.

If called with exactly one hash reference, it updates the hash with the given
key/value pairs, then returns the hash in list context, or a reference to the
hash in scalar context.

=item result_clear

    $obj->result_clear;

Deletes all keys and values from the hash.

=item result_delete

    $obj->result_delete(@keys);

Takes a list of keys and deletes those keys from the hash.

=item result_exists

    if ($obj->result_exists($key)) { ... }

Takes a key and returns a true value if the key exists in the hash, and a
false value otherwise.

=item result_keys

    my @keys = $obj->result_keys;

Returns a list of all hash keys in no particular order.

=item result_values

    my @values = $obj->result_values;

Returns a list of all hash values in no particular order.

=item set_dirs

    $obj->set_dirs(1 => $x, 5 => $y);

Takes a list of index/value pairs and for each pair it sets the array element
at the indicated index to the indicated value. Returns the number of elements
that have been set.

=item set_verbose

    $obj->set_verbose;

Sets the boolean value to 1.

=item shift_dirs

    my $value = $obj->shift_dirs;

Shifts the first element off the array, returning it.

=item splice_dirs

    $obj->splice_dirs(2, 1, $x, $y);
    $obj->splice_dirs(-1);
    $obj->splice_dirs(0, -1);

Takes three arguments: An offset, a length and a list.

Removes the elements designated by the offset and the length from the array,
and replaces them with the elements of the list, if any. In list context,
returns the elements removed from the array. In scalar context, returns the
last element removed, or C<undef> if no elements are removed. The array grows
or shrinks as necessary. If the offset is negative then it starts that far
from the end of the array. If the length is omitted, removes everything from
the offset onward. If the length is negative, removes the elements from the
offset onward except for -length elements at the end of the array. If both the
offset and the length are omitted, removes everything. If the offset is past
the end of the array, it issues a warning, and splices at the end of the
array.

=item unshift_dirs

    $obj->unshift_dirs(@values);

Unshifts elements onto the beginning of the array.

=item values_result

    my @values = $obj->values_result;

Returns a list of all hash values in no particular order.

=item verbose

    $obj->verbose($value);
    my $value = $obj->verbose;

If called without an argument, returns the boolean value (0 or 1). If called
with an argument, it normalizes it to the boolean value. That is, the values
0, undef and the empty string become 0; everything else becomes 1.

=item verbose_clear

    $obj->verbose_clear;

Clears the boolean value by setting it to 0.

=item verbose_set

    $obj->verbose_set;

Sets the boolean value to 1.

=item parse

Assumes that C<dir()>, and optionally C<verbose()> and C<min_length()>, have
been set and starts to look in the directories for files ending in C<.pm>. For
each file it gathers information using C<gather()>.

Returns the Vim::Complete object so method calls can be chained as seen in the
L</SYNOPSIS>.

=item report

Takes all the gathered findings and returns the list of identifiers. Returns
an array in list context, or a reference to the array in scalar context.

=item report_to_file

Takes as argument a filename. Writes the report generated by C<report()> to
the file.

=item gather

Takes a filename of a module, parses the source code and makes a note of the
package names, subroutine names and variable names it sees.

This method is called by C<parse()>; it is unlikely that you want to call it
yourself.

=back

Vim::Complete inherits from L<Class::Accessor::Complex>.

The superclass L<Class::Accessor::Complex> defines these methods and
functions:

    mk_abstract_accessors(), mk_array_accessors(), mk_boolean_accessors(),
    mk_class_array_accessors(), mk_class_hash_accessors(),
    mk_class_scalar_accessors(), mk_concat_accessors(),
    mk_forward_accessors(), mk_hash_accessors(), mk_integer_accessors(),
    mk_new(), mk_object_accessors(), mk_scalar_accessors(),
    mk_set_accessors(), mk_singleton()

The superclass L<Class::Accessor> defines these methods and functions:

    _carp(), _croak(), _mk_accessors(), accessor_name_for(),
    best_practice_accessor_name_for(), best_practice_mutator_name_for(),
    follow_best_practice(), get(), make_accessor(), make_ro_accessor(),
    make_wo_accessor(), mk_accessors(), mk_ro_accessors(),
    mk_wo_accessors(), mutator_name_for(), set()

The superclass L<Class::Accessor::Installer> defines these methods and
functions:

    install_accessor()

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through the web interface at
L<http://rt.cpan.org>.

=head1 INSTALLATION

See perlmodinstall for information and options on installing Perl modules.

=head1 AVAILABILITY

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit <http://www.perl.com/CPAN/> to find a CPAN
site near you. Or see <http://www.perl.com/CPAN/authors/id/M/MA/MARCEL/>.

=head1 AUTHORS

Marcel GrE<uuml>nauer, C<< <marcel@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2007-2008 by the authors.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

