#!/usr/bin/perl -w

use strict;

use AnyEvent::HTTP; # ������砥� �३���� AnyEvent 

my $cv = AnyEvent->condvar;

# ����砥� ᯨ᮪ URL �� STDIN
my @urls; # ���ᨢ ��� �࠭���� ᯨ᪠ URL 
while(1) {
	my $url = <STDIN>; # �ਭ����� ��।��� URL �� STDIN 
	chomp( $url ) if defined $url;

	last unless $url;
	push @urls, $url;
}

my %stat; # �� ��� �࠭���� ���⥫쭮�� �맮�� URL

foreach my $url ( @urls ) { # ��뢠�� �� URL � ����������饬 ०���

	$cv->begin;

	# ����� �������� URL, � ���஬� ��⮢� ��������. 
	# �� � ������� �뢮� ��� ������ ���������. ���⮬� �� �뢮���
	# print "GET $url\n";

	$stat{ $url } = AnyEvent->time; # ���������� �६� ����᪠ �맮��

	my $guard; $guard = http_get( $url,
		sub {
			$stat{ $url } = AnyEvent->time - $stat{ $url }; # ��।��塞 �६�, ���஥ ���ॡ������� �� �맮� URL
			undef $guard; 
			my ( $body, $hdr ) = @_;

			# ࠧ��ࠥ� �⢥�
			if ( $hdr->{ Status } =~ /^2/ ) { # ��⠥� ����� 㤮���⢮�⥫�� � �뢮��� ⥪�� ��࠭���
				# ����� �뢮���� ᮤ�ন��� ��࠭���
				# print $body; 

				# � ����� �뢮���� ����� � url
				print $hdr->{ Status }.' => '.$url."\n";

			} else { # ����祭� ᮮ�饭�� �� �訡��.
				# �� ⮦� �⢥� - �뢮��� ᮮ�饭��
				print	'Error for '.$url.
						'. Code: '.$hdr->{Status}.
						', Reason: '.$hdr->{Reason}.
						"\n";
			}
			$cv->end;
		}
	);
}

$cv->recv; # ������������ ���� �����祭�

# �뢮��� ����⨪� �� ᪮��� �맮�� ������� �ૠ
# ᭠砫� ������, ��⮬ ��������
print "\nAll calls were done. Call duration statistic here:\n";
foreach ( sort { $stat{ $a } <=> $stat{ $b } } keys %stat ) {
	print $stat{ $_ }.' sec for '.$_."\n";
}
