package Analizo::Extractor::Clang;

use strict;

use base qw(Analizo::Extractor);

use File::Basename;

use Clang;

sub new {
  my $package = shift;
  return bless { files => [], visited_nodes => { }, @_ }, $package;
}

sub actually_process($@) {
  my ($self, @input) = @_;

  my $index = Clang::Index -> new(0);
  my $is_c_code = 1;
  if (grep { $_ =~ /\.(cc|cxx|cpp)$/ } @input) {
    $is_c_code = 0;
  }

  for my $file (@input) {
    my $tunit = $index->parse($file);
    my $node = $tunit->cursor;
    $self->_visit_node($node, $is_c_code);
  }
}

sub _visit_node($$$) {
    my ($self, $node, $is_c_code) = @_;

    my $name = $node->spelling;
    my $kind = $node->kind->spelling;
    my ($file, $line, $column) = $node->location();

    print STDERR "$name($kind)\n" if $ENV{DEBUG}; # FIXME

    # FIXME find other way of skipping nodes outside of the analyzed tree?
    if ($file =~ m/^\/usr/) {
        return;
    }

    if ($kind eq 'ClassDecl') {
      $self->model->declare_module($name);
      my $superclass = _find_superclass($node);
      if ($superclass) {
        if (! grep { $_ eq $superclass } $self->model->inheritance($name)) {
          $self->model->add_inheritance($node->spelling, $superclass);
        }
      }
      for my $method (_find_methods($node)) {
        $self->model->declare_function($name, $method, $method);
      }
    }

    if ($is_c_code && $kind eq 'TranslationUnit') {
      my $module_name = basename($name);
      $module_name =~ s/\.\w+$//;
      $self->model->declare_module($module_name);
    }

    my $children = $node->children;
    foreach my $child(@$children) {
      $self->_visit_node($child);
    }
}

sub _find_superclass($) {
  my ($node) = @_;
  for my $child (@{$node->children}) {
    if ($child->kind->spelling eq 'C++ base class specifier') {
      my $name = $child->spelling;
      $name =~ s/class //; # FIXME should follow the reference instead
      return $name;
    }
  }
  return undef;
}

sub _find_methods($) {
  my ($node) = @_;
  my @list = ();
  for my $child (@{$node->children}) {
    if ($child->kind->spelling eq 'CXXMethod') {
      push @list, $child->spelling;
    }
  }
  return @list;
}

1;
