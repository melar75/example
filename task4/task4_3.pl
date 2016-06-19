#!/usr/bin/perl -w

use strict;

use AnyEvent::HTTP; # подключаем фреймворк AnyEvent 

my $cv = AnyEvent->condvar;

# Получаем список URL из STDIN
my @urls; # массив для хранения списка URL 
while(1) {
	my $url = <STDIN>; # принимаем очередной URL на STDIN 
	chomp( $url ) if defined $url;

	last unless $url;
	push @urls, $url;
}

my %stat; # хеш для хранения длительности вызова URL

foreach my $url ( @urls ) { # вызываем все URL в неблокирующем режиме

	$cv->begin;

	# можно напечатать URL, к которому готовы обратиться. 
	# Но в задании вывод этих данных отсутствует. Поэтому не выводим
	# print "GET $url\n";

	$stat{ $url } = AnyEvent->time; # запоминаем время запуска вызова

	my $guard; $guard = http_get( $url,
		sub {
			$stat{ $url } = AnyEvent->time - $stat{ $url }; # определяем время, которое потребовалось на вызов URL
			undef $guard; 
			my ( $body, $hdr ) = @_;

			# разбираем ответ
			if ( $hdr->{ Status } =~ /^2/ ) { # считаем статус удовлетворительным и выводим текст страницы
				# можно выводить содержимое страницы
				# print $body; 

				# а можно выводить статус и url
				print $hdr->{ Status }.' => '.$url."\n";

			} else { # получено сообщение об ошибке.
				# Это тоже ответ - выводим сообщение
				print	'Error for '.$url.
						'. Code: '.$hdr->{Status}.
						', Reason: '.$hdr->{Reason}.
						"\n";
			}
			$cv->end;
		}
	);
}

$cv->recv; # неблокирующая часть закончена

# Выводим статистику по скорости вызова каждого урла
# сначала быстрые, потом медленные
print "\nAll calls were done. Call duration statistic here:\n";
foreach ( sort { $stat{ $a } <=> $stat{ $b } } keys %stat ) {
	print $stat{ $_ }.' sec for '.$_."\n";
}
