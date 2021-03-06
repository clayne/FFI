package FFI::Library;

use strict;
use warnings;
use Carp ();
use constant _is_win => $^O =~ /^(MSWin32|cygwin|msys2?)$/;

# ABSTRACT: Perl Access to Dynamically Loaded Libraries
# VERSION

sub new
{
  my($class, $libname, $flags) = @_;
  Carp::croak('Usage: $lib = FFI::Library->new($filename [, $flags ])')
    unless @_ <= 3;

  $flags ||= 0;

  if(! defined $libname)
  {
    return bless {
      impl => 'null',
    }, $class;
  }
  elsif(ref $libname and int($libname) == int(\$0))
  {
    return $class->_dl_impl(undef, undef);
  }
  elsif(_is_win)
  {
    return $class->_dl_impl($libname, undef);
  }
  elsif(-e $libname)
  {
    return $class->_dl_impl(
      $libname,
      $flags == 0x01 ? FFI::Platypus::Lang::DL::RTLD_GLOBAL() : undef,
    );
  }
  else
  {
    require DynaLoader;
    my $so = DynaLoader::dl_findfile($libname) || $libname;
    my $handle = DynaLoader::dl_load_file($so, $flags || 0);
    return unless $handle;  ## no critic (Freenode::EmptyReturn)
    return bless {
      impl => 'dynaloader',
      handle => $handle,
    }, $class;
  }
}

sub _dl_impl
{
  my($class, $path, $flags) = @_;
  require FFI::Platypus::DL;
  $flags = FFI::Platypus::DL::RTLD_PLATYPUS_DEFAULT()
    unless defined $flags;
  my $handle = FFI::Platypus::DL::dlopen($path, $flags);
  return unless defined $handle;
  bless { impl => 'dl', handle => $handle }, $class;
}

sub address
{
  my($self, $name) = @_;

  if($self->{impl} eq 'dl')
  {
    return FFI::Platypus::DL::dlsym($self->{handle}, $name);
  }
  elsif($self->{impl} eq 'dynaloader')
  {
    return DynaLoader::dl_find_symbol($self->{handle}, $name);
  }
  elsif($self->{impl} eq 'null')
  {
    return;  ## no critic (Freenode::EmptyReturn)
  }
  else
  {
    Carp::croak("Unknown implementaton: @{[ $self->{impl} ]}");
  }
}

sub function
{
  my($self, $name, $sig) = @_;

  my $addr = $self->address($name);

  Carp::croak("Unknown function $name")
    unless defined $addr;

  require FFI;
  sub { FFI::call($addr, $sig, @_) };
}

sub DESTROY
{
  my($self) = @_;

  if($self->{impl} eq 'dl')
  {
    FFI::Platypus::DL::dlclose($self->{handle});
  }
  elsif($self->{impl} eq 'dynaloader')
  {
    DynaLoader::dl_free_file($self->{handle})
      if defined &DynaLoader::dl_free_file;
  }
  elsif($self->{impl} eq 'null')
  {
    # do nothing
  }
  else
  {
    Carp::croak("Unknown implementaton: @{[ $self->{impl} ]}");
  }
}

1;

=head1 SYNOPSIS

 # call function from arbitrary dynamic library
 use FFI::Library;
 $lib = FFI::Library->new("mylib");
 $fn = $lib->function("fn", "signature");
 $ret = $fn->(...);

 # call function from libc
 $clib_file = ($^O eq "MSWin32") ? "MSVCRT40.DLL" : "-lc";
 $clib = FFI::Library->new($clib_file);
 $strlen = $clib->function("strlen", "cIp");
 $n = $strlen->($my_string);

=head1 DESCRIPTION

B<NOTE>: Newer and better maintained FFI modules such as L<FFI::Platypus>
provide more functionality and so it is strongly recommend that you use
one of them for new projects and even consider migrating to one of
them for existing projects.

This module provides access from Perl to functions exported from dynamically
linked libraries. Functions are described by C<signatures>, for details of
which see the L<FFI> module's documentation.

=head1 CONSTRUCTOR

=head2 new

 my $lib = FFI::Library->new($libname);

Creates an instance of C<FFI::Library>.

=head1 FUNCTIONS

=head2 address

 my $address = $lib->address($function_name);

Returns the symbol of the given function.  Returns C<undef> if
the symbol is not found.

=head2 function

 my $sub = $lib->function($function_name, $signature);

Creates a code-reference like object which you can call.

=head1 EXAMPLES

 $clib_file = ($^O eq "MSWin32") ? "MSVCRT40.DLL" : "-lc";
 $clib = FFI::Library->new($clib_file);
 $strlen = $clib->function("strlen", "cIp");
 $n = $strlen->($my_string);

=head1 SUPPORT

Please open any support tickets with this project's GitHub repository 
here:

L<https://github.com/PerlFFI/FFI/issues>

=head1 SEE ALSO

=over 4

=item L<FFI>

Low level interface to ffcall that this module is based on

=item L<FFI::CheckLib>

Portable functions for finding libraries.

=item L<FFI::Platypus>

Platypus is another FFI interface based on libffi.  It has a more
extensive feature set, and libffi has a less restrictive license.

=back
