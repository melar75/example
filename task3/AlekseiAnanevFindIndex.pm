package AlekseiAnanevFindIndex;

##################################################
# MODULE: AlekseiAnanevFindIndex
# 	Тестовое задание Ананьева Алексея
#	melar@gotovo.org
#
##################################################

# CONSTRUCTOR: new
#

sub new () {
	my $pkg = shift; # получаем имя класса
	my $self; { my %hash; $self = bless(\%hash, $pkg); }

	return $self;
}

# FUNCTION: find
#	Метод, поиска индекса ближайшего значения в отсортированном по возрастанию массиве чисел
#
# Parameters: 
#	$value - искомое значение 
#	$arr_ref - ссылка на массив из большого числа элементов (числа), отсортированный по возрастанию
#
# Returns:
#	массив из двух элементов:
#	[0] - найденный индекс,
#	[1] - число шагов (число сравнений).
#

sub find ($$) {
	my $pkg = shift;

	my $value = shift;		# искомое значение
	my $arr_ref = shift;	# ссылка на массив

	my $n = $#$arr_ref;	# количество элементов массива
	my $step = 0; # счетчик шагов поиска

	# проверка позиции за пределами массива ( шанс выполнить поиск без прохода массива )
	return 0, $step if $value <= $arr_ref->[ 0 ];
	return $n, $step if $value >= $arr_ref->[ $n ];

	my $left = 0; 	# левая граница поиска
	my $right = $n;	# правая граница поиска

	# алгоритм бинарного поиска требуемого интервала
	while ( $left < $right - 1 ) {
		$step++; # считаем шаги
		my $node = ( $left + $right ) >> 1;
		if ( $value >= $arr_ref->[ $node ] ) { $left = $node }
			else { $right = $node }
	}

	# left и right содержат левую и правую границу относительно числа
	# возвращаем индекс элемента, ближнего к значению value
	if ( ( $arr_ref->[ $right ] - $arr_ref->[ $left ] ) / 2 + $arr_ref->[ $left ] > $value  ) {
		return $left, $step; # значение ближе к левой границе
	} else {
		return $right, $step; # значение ближе к правой границе
	}
}

1;
