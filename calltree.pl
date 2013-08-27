#!/usr/bin/perl

%hash  = ();
@stack = ();
@calltree = ();

$argc = @ARGV;
$file = shift @ARGV;
@addr = @ARGV;

if ($argc < 2) {
	print "Usage: $0 <disassemly file path> <function address>\n";
	exit;
}

fileRead($file);
#hashDump();
foreach my $addr (@addr) {
	@stack = (undef);
	@calltree = (undef);

	calltreeFind($addr);

	# print the max call stack
	print $hash->{$addr}->[0], ",", stackSize(@calltree);	
	stackDump(@calltree);
	print "\n";
	#print $addr;
}


#
# read disassemly file
#
sub fileRead
{
	my ($file) = @_;
	my ($addr, $func);
	
	open(FILE, $file) || die "Cann't Open Disassembly File $file";
	while(<FILE>)
	{
		if (/^(\w*)\s*<(.*)>:*/) {
			# Get Function name and address
			#00000000 <Spca5000DriverDiskSectorCount_C>:
			$addr = $1;
			$func = $2;

			#function name
			$hash->{$addr}->[0] = $func;
			#stack size
			$hash->{$addr}->[1] = 0;
			#sub routines count
			$hash->{$addr}->[2] = 0;
		}
		
		if (/^\s*\w+:\s*\w+\s*addiu\s*\$sp,\$sp,-(.+)\r/)
		{			
			# Get Stack Size (for MIPS instruction only)
			#   0:	27bdffe8 	addiu	$sp,$sp,-24
			
			$hash->{$addr}->[1] += $1;
		}

		if (/^\s*\w+:\s*\w+\s*jal\s+(.+)\s+<(.*)>/) {
			# Get sub routines count (for MIPS instruction only)
			# 64:	0c000000 	jal	0 <vfsPosixTimeConvert>

			#sub routines count++
			$hash->{$addr}->[2] ++;
			#push sub routines address into array
			push(@{$hash->{$addr}}, $1);
		}

	}

	close(FILE);
}

#
# dump hash
#
sub hashDump
{
	print "addr,func,stack size,sub routines\n";

	foreach my $addr (sort keys (%{$hash}))
	{
		print "$addr,",join(",", @{$hash->{$addr}}),"\n";
	}	
}

#
# stack size
#
sub stackSize
{
	my $size = 0;
	my @stack = @_;

	foreach my $addr (@stack) {
		$size += $hash->{$addr}->[1];
	}

	return $size;
}

#
# dump call stack
#
sub stackDump
{
	my $depth = 0;
	my @stack = @_;

	foreach my $addr (@stack) {
		print "$hash->{$addr}->[0], $hash->{$addr}->[1]\n";
	}
}

#
# if the item is exised in stack or not?
#
sub stackExist
{
	#argments list
	my ($func) = @_;
	my $exist = 0;

	foreach my $addr (@stack) {
		if ($addr eq $func) {
			$exist = 1;
			last;
		}
	}

	return $exist;
}

#
# push max calltree
#
sub calltreePush
{
	#stackDump(@stack);
	if (stackSize(@stack) > stackSize(@calltree)) {
		@calltree = @stack;
	}
}

#
# found all calltree
#
sub calltreeFind
{
	#argments list, function address
	my ($addr) =  @_;
	#sub routines count
	my $count = $hash->{$addr}->[2];

	push(@stack, $addr);

	for (my $i = 0; $i < $count; $i++) {
		my $func = $hash->{$addr}->[$i+3];

		if ($hash->{$func}->[0] eq "printf") {
			calltreePush();
			next;
		}
		if ($hash->{$func}->[0] eq "sprintf") {
			calltreePush();
			next;
		}
		if ($hash->{$func}->[0] eq "profLogCallStack") {
			calltreePush();
			next;
		}
		if ($hash->{$func}->[0] eq "profLogPrintf") {
			calltreePush();
			next;
		}
		if ($hash->{$func}->[0] eq "dbgAssert") {
			calltreePush();
			next;
		}

		# avoid recursion call
		if (stackExist($func)) {
			calltreePush();
			next;
		}

		calltreeFind($func);
	}
	if ($count == 0) {
		calltreePush();
	}

	pop(@stack);
}
