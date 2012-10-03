package VK::MP3;

use strict;
use warnings;
use utf8;

use LWP;
use LWP::Protocol::https;
use HTML::Entities;
use URI::Escape;

our $VERSION = 0.05;

sub new {
  my ($class, %args) = @_;
  die 'USAGE: VK::MP3->new(login => ..., password => ...)'
    unless _valid_new_args(\%args);

  my $self = { 
      ua => _create_ua(),
      login => $args{login},
      password => $args{password},
    };
  bless $self, $class;

  die 'ERROR: login failed' unless($self->_login());

  return $self;
}

sub search {
  my ($self, $query) = @_;

  my $res = $self->{ua}->get('http://vk.com/search?c[section]=audio&c[q]='.uri_escape_utf8($query));
  die 'LWP: '.$res->status_line unless $res->is_success;

  my @matches = $res->decoded_content =~  m'<input type="hidden" id="audio_info(.*?)</tbody></table>'sgi;

  my @rslt;
  push @rslt, $self->_parse_found_item($_) for(@matches);
  @rslt = grep { defined $_ } @rslt;

  return \@rslt;
}

sub get_playlist {
  my ($self) = @_;
  my $res;

  $res = $self->{ua}->get('http://vk.com/audio'); # we need cookies
  return 0 unless $res->is_success;

  $res = $self->{ua}->post('http://vk.com/audio', {
      load_audios_silent => 1,
      al => 1,
      gid => 0,
      id => $self->{id},
    }, 
      'Accept-Encoding' => 'gzip,deflate,sdch',
      'Referer' => 'http://vk.com/audio',
      'Origin' => 'http://vk.com',
      'User-Agent' => 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.1 '.
                      '(KHTML, like Gecko) Chrome/21.0.1180.89 Safari/537.1',
      'X-Requested-With' => 'XMLHttpRequest',
    );  
  return 0 unless $res->is_success;
  warn $res->decoded_content;
 
}

sub _parse_found_item {
  my ($self, $str) = @_;
  my ($name) = $str =~ m{<div class="title_wrap fl_l".*?>(.*?)</div>}si;
  return undef unless $name;
 
  $name =~ s/<[^>]+>//g;
  $name =~ s/ ?\([^\(]*$//;
  $name = decode_entities($name);

  my ($duration) = $str =~ m{<div class="duration fl_r".*?>(\d+:\d+)</div>}i;
  my ($link) = $str =~ m{value="(http://[^",]+\.mp3)}i;

  if($duration) {
    my ($min, $sec) = split /:/, $duration, 2;
    $duration = $min * 60 + $sec;
  } else {
    $duration = 0;
  }
  
  return { name => $name, duration => $duration, link => $link };
}

sub _login {
  my $self = shift;
  my $res = $self->{ua}->post('https://login.vk.com/?act=login', {
      email => $self->{login},
      pass => $self->{password},
    });  

  if(  $res->is_success &&
      ($res->decoded_content =~ /var\s+vk\s*=\s*\{[^\{\}]*?id\s*\:\s*(\d+)/i) ) {
    $self->{id} = $1;
    return 1;
  }
  return 0;
}

sub _create_ua {
  my $ua = LWP::UserAgent->new();

  push @{ $ua->requests_redirectable }, 'POST';
  $ua->ssl_opts(verify_hostname => 0);
  $ua->cookie_jar( {} );

  return $ua;
}

sub _valid_new_args {
  my $args = shift;
  return 0 unless ref($args) eq 'HASH';
  for(qw/login password/) {
    return 0 unless defined($args->{$_}) && (ref($args->{$_}) eq '');
  }
  return 1;
}

1;

__END__

=head1 NAME

VK::MP3 - searches for mp3 on vkontakte.ru, also known as vk.com.

=head1 SYNOPSIS

    use VK::MP3;
     
    my $vk = VK::MP3->new(login => 'user', password => 'secret');
    my $rslt = $vk->search('Nightwish');

    for (@{$rslt}) {
        # $_->{name}, $_->{duration}, $_->{link}
    }

=head1 DESCRIPTION

B<VK::MP3> helps you to find direct URL's of audio files on vk.com (via regular expressions and LWP).

This package also includes B<vkmp3> utility, that allows you to download found mp3.

=head1 METHODS

=head2 C<new>

    my $vk = VK::MP3->new(login => $login, password => $password)

Constructs a new C<VK::MP3> object and logs on vk.com. Throws exception in case of any error.

=head2 C<search>

    my $rslt = $vk->search($query)

Results, found by $query.

=head2 C<get_playlist>

    my $rslt = $vk->get_playlist()

Returns your playlist.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc VK::MP3

You can also look for information at:

=over 3

=item * GitHub

L<https://github.com/afiskon/p5-vk-mp3>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/VK-MP3>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/VK-MP3>

=back

=head1 SEE ALSO

L<VK>, L<VKontakte::API>, L<LWP::UserAgent>.

=head1 AUTHOR

Alexandr Alexeev, <eax at cpan.org> (L<http://eax.me/>)

=head1 COPYRIGHT

Copyright 2011-2012 by Alexandr Alexeev

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
