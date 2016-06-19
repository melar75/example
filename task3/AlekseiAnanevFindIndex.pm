package AlekseiAnanevFindIndex;

##################################################
# MODULE: AlekseiAnanevFindIndex
# 	�������� ������� �������� �������
#	melar@gotovo.org
#
##################################################

# CONSTRUCTOR: new
#

sub new () {
	my $pkg = shift; # �������� ��� ������
	my $self; { my %hash; $self = bless(\%hash, $pkg); }

	return $self;
}

# FUNCTION: find
#	�����, ������ ������� ���������� �������� � ��������������� �� ����������� ������� �����
#
# Parameters: 
#	$value - ������� �������� 
#	$arr_ref - ������ �� ������ �� �������� ����� ��������� (�����), ��������������� �� �����������
#
# Returns:
#	������ �� ���� ���������:
#	[0] - ��������� ������,
#	[1] - ����� ����� (����� ���������).
#

sub find ($$) {
	my $pkg = shift;

	my $value = shift;		# ������� ��������
	my $arr_ref = shift;	# ������ �� ������

	my $n = $#$arr_ref;	# ���������� ��������� �������
	my $step = 0; # ������� ����� ������

	# �������� ������� �� ��������� ������� ( ���� ��������� ����� ��� ������� ������� )
	return 0, $step if $value <= $arr_ref->[ 0 ];
	return $n, $step if $value >= $arr_ref->[ $n ];

	my $left = 0; 	# ����� ������� ������
	my $right = $n;	# ������ ������� ������

	# �������� ��������� ������ ���������� ���������
	while ( $left < $right - 1 ) {
		$step++; # ������� ����
		my $node = ( $left + $right ) >> 1;
		if ( $value >= $arr_ref->[ $node ] ) { $left = $node }
			else { $right = $node }
	}

	# left � right �������� ����� � ������ ������� ������������ �����
	# ���������� ������ ��������, �������� � �������� value
	if ( ( $arr_ref->[ $right ] - $arr_ref->[ $left ] ) / 2 + $arr_ref->[ $left ] > $value  ) {
		return $left, $step; # �������� ����� � ����� �������
	} else {
		return $right, $step; # �������� ����� � ������ �������
	}
}

1;
