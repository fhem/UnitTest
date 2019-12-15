######################################################################
# 98_unittest.pm 
#
# The file is part of the development SIGNALduino project
#
# https://github.com/RFD-FHEM/UnitTest | https://github.com/fhem/UnitTest
#
# 2018 | 2019 - sidey79
######################################################################


package main;
use v5.14;               # All 5.14 features including "say".
use strict;
use warnings;
# Laden evtl. abhängiger Perl- bzw. FHEM-Module
use Mock::Sub (no_warnings => 1);
use Test::More;
use Data::Dumper qw(Dumper);
use JSON qw(encode_json decode_json);
use File::Basename;
use Storable (qw/dclone/);

# FHEM weitee Variablen
our %defs;
our %attr;


$Storable::Deparse = 1;  # Needs to be set to true as per docs to allow stoe of coderefs
$Storable::Eval    = 1;  # Same as above


# FHEM Modulfunktionen

sub UnitTest_Initialize() {
	my ($hash) = @_;
	$hash->{DefFn}         = "UnitTest_Define";
	$hash->{UndefFn}       = "UnitTest_Undef";
	$hash->{NotifyFn}      = "UnitTest_Notify";
	$hash->{AttrFn}        = "UnitTest_Attr";
	$hash->{AttrList}      = "do_not_notify:1,0 disable:0,1 " .
							 "$readingFnAttributes ";
}

sub UnitTest_Define() {
	my ( $hash, $def ) = @_;
   
    my ($name,$type,$target,$cmd) = split('[ \t]+', $def,4);

	#if (!$cmd || (not $cmd =~ m/^[(].*[)]$/g)) {
	if (!$cmd || $cmd !~ m/(?:\(.*\)).*$/s) {
		my $msg = "wrong syntax: define <name> UnitTest <name of target device> (Test Code in Perl)";
		Log3 undef, 2, $name.": ".$msg;
		Log3 undef, 5, "$name: cmd was: $cmd";
		return $msg;
	}
	$hash->{targetDevice}  = $target;
	if (!IsDevice($target))
	{
		my $msg = "$target is not an existing Device";
		Log3 undef, 2, $name.": ".$msg;
		return $msg;
		
	}
	Log3 $name, 2, "$name: Defined unittest for target: ".$hash->{targetDevice} if ($hash->{targetDevice});
	Log3 $name, 5, "$name: DEV is $cmd";
    
	($hash->{'.testcode'}) = $cmd =~ /(\{[^}{]*(?:(?R)[^}{]*)*+\})/;
	Log3 $name, 5, "$name: Loaded this code ".$hash->{'.testcode'} if ($hash->{'.testcode'});
    
	$hash->{name}  = $name;
	if (!IsDisabled($name)) {
		readingsSingleUpdate($hash, "state", "waiting", 1);

		## Test starten wenn Fhem bereits initialisiert wurde	
		if  ($init_done) {
			InternalTimer(gettimeofday()+1, 'UnitTest_Test_generic',$hash,0);
		}
	} else {
		readingsSingleUpdate($hash, "state", "inactive", 1);
	}
	
    $hash->{test_output}="";
    $hash->{test_failure}="";
    $hash->{todo_output}="";

    ### Attributes ###
    if ( $init_done == 1 ) {
		$attr{$name}{room}	= "UnitTest" if( not defined( $attr{$name}{room} ) );
    }

    return undef;

}

sub UnitTest_Attr(@) {
	my ($cmd, $name, $attrName, $attrValue) = @_;
	my $hash = $defs{$name};

	if ($cmd eq "set" && $attrName eq "disable" && $attrValue eq "1") {
		$hash->{test_failure}="";
		$hash->{test_output}="";
		readingsBeginUpdate($hash);
		readingsBulkUpdate($hash, "test_output", $hash->{test_output} , 1);
		readingsBulkUpdate($hash, "test_failure", $hash->{test_failure} , 1);
		readingsBulkUpdate($hash, "state", "inactive", 1);
		readingsEndUpdate($hash,1);
		
		Log3 $name, 3, "$name: is disabled";
	}

	if ($cmd eq "set" && $attrName eq "disable" && $attrValue eq "0" || $cmd eq "del" && $attrName eq "disable") {
		readingsSingleUpdate($hash, "state", "waiting", 1);
		Log3 $name, 3, "$name: is enabled";
		
		InternalTimer(gettimeofday()+1, 'UnitTest_Test_generic',$hash,0);
	}
	return undef;
}

sub UnitTest_Undef($$)    
{                     
	return undef;                  
}

sub UnitTest_Notify($$)
{
  my ($own_hash, $dev_hash) = @_;
  my $ownName = $own_hash->{NAME}; # own name / hash

  return "" if(IsDisabled($ownName)); # Return without any further action if the module is disabled

  my $devName = $dev_hash->{NAME}; # Device that created the events

  my $events = deviceEvents($dev_hash,1);
  
  return if( !$events );

  foreach my $event (@{$events}) {
    $event = "" if(!defined($event));
    if ($devName eq "global" && $event eq "INITIALIZED")
    {
    	#UnitTest_Test_1($own_hash);
    	#UnitTest_Test_2($own_hash);
    	
    	
    	InternalTimer(gettimeofday()+4, 'UnitTest_Test_generic',$own_hash,0);       # verzoegern bis alle Attribute eingelesen sind, da das SIGNALduino Modul keinen Event erzeugt, wenn dies erfolgt ist
    	
    }
    # Examples:
    # $event = "readingname: value" 
    # or
    # $event = "INITIALIZED" (for $devName equal "global")
    #
    # processing $event with further code
  }
}


sub UnitTest_run
{
	my $hash = shift;
	
	my $name = $hash->{NAME};
	my $target = $hash->{targetDevice};
	my $targetHash = $defs{$target};
	
	# Logfile can be changed for the forked process, but this has no effect, if this process is done.
	my $original_logfile = $attr{global}{logfile};
	my %copyOfTargetHash = %{ dclone( $defs{$target} ) };
	
		
	GlobalAttr("set", "global", "logfile", "./log/fhem-%Y-%m-$name.log");
	CommandAttr(undef,"global logfile ./log/fhem-%Y-%m-$name.log");
	
	#todo: LogFile has the wrong filename
	$hash->{LOGFILE} = "/fhem/FileLog_logWrapper?dev=Logfile&type=text&file=".basename(InternalVal('Logfile', 'currentlogfile', 'noval')); # save current logfile into internal, to provide a link<a
	
	Log3 $name, 3, "---- Test $name starts here ---->";
	
	my %test_results;
	$test_results{name} = $name ;
	$test_results{test_output}="";
	$test_results{test_failure}="";
	$test_results{todo_output}="";
	# Redirect Test Output to internals
	Test::More->builder->output(\$test_results{test_output});
	Test::More->builder->failure_output(\$test_results{test_failure});
	Test::More->builder->todo_output(\$test_results{todo_output});
	
	# Disable warnings for prototype mismatch
	$SIG{__WARN__} = sub {CORE::say $_[0] if $_[0] !~ /Prototype/};
	
	Log3 $name, 5, "$name/UnitTest_run: Running now this code ".$hash->{'.testcode'} if ($hash->{'.testcode'});
   	$targetHash->{STATE} = "under unittest";
	
	my $result =eval $hash->{'.testcode'}." 1;"  if ($hash->{'.testcode'});
	
	# Reset output handlers
	Test::More->builder->reset;
	
	# enable warnings for prototype mismatch
	$SIG{__WARN__} = sub {CORE::say $_[0]};
	
	unless ($result) {
		$test_results{eval} = $result;
		$test_results{error} = $@;
		Log3 $name, 5, "$name/UnitTest_run: return from eval was with error $@" ;
		$test_results{test_failure} = $test_results{test_failure}. $test_results{error}."\n";
	}
	if ($test_results{eval})
	{
		Log3 $name, 5, "$name/UnitTest_run: Test has following result: $test_results{eval}" ;
	}

	my @test_output_list = split "\n",$test_results{test_output};	
    foreach my $logline(@test_output_list) {
    		Log3 $name, 3, $logline;
    	
    }
    my @test_failure_list = split "\n",$test_results{test_failure};	
    foreach my $logline(@test_failure_list) {
    		Log3 $name, 3, $logline;
    }
    my @test_todo_list = split "\n",$test_results{test_todo} if $test_results{test_todo};
    foreach my $logline(@test_todo_list) {
    		Log3 $name, 3, $logline;
    }
	
	Log3 $name, 3, "<---- Test $name ends here ----";
	#$attr{global}{logfile}=$original_logfile;
	
	#restore some defaults
	GlobalAttr("set", "global", "logfile", $original_logfile);
	CommandAttr(undef,"global logfile $original_logfile");
	delete($defs{$target});
	$defs{$target} = \%copyOfTargetHash;
	
	return encode_json(\%test_results);
	
}
sub UnitTest_aborted($)
{
  my ($hash) = @_;


  Log3 $hash->{NAME}, 3, $hash->{NAME}."/UnitTest_aborted: BlockingCall was aborted";

  RemoveInternalTimer($hash);
  
  readingsBeginUpdate($hash);
  reeadingsBulkUpdate($hash, "state", "aborted", 1);
  readingsEndUpdate($hash,1);
  
}


sub UnitTest_finished
{
	use Data::Dumper;
	my $json=shift;
	#print Dumper(\$json);
	my $test_results =decode_json($json);
#	print Dumper(\%test_results);

	
	my $hash =  $defs{$test_results->{name}};	
	
	my $name = $hash->{NAME};

	

	#Debug "trap_results:".Dumper($test_results);
	
	if ($test_results->{eval})
	{
		Log3 $name, 5, "$name/UnitTest_finished: Test has following result: $test_results->{eval}" ;
	}


	my @test_output_list = split "\n",$test_results->{test_output};	
    foreach my $logline(@test_output_list) {
    		Log3 $name, 3, $logline;
    	
    }
    my @test_failure_list = split "\n",$test_results->{test_failure};	
    foreach my $logline(@test_failure_list) {
    		Log3 $name, 3, $logline;
    }
    my @test_todo_list = split "\n",$test_results->{test_todo} if $test_results->{test_todo};
    foreach my $logline(@test_todo_list) {
    		Log3 $name, 3, $logline;
    }
	
	Log3 $name, 3, "<---- Test $name ends here ----";
	
	readingsBeginUpdate($hash);
	readingsBulkUpdate($hash, "test_output", $test_results->{test_output} , 1);
	readingsBulkUpdate($hash, "test_failure", $test_results->{test_failure} , 1);
	readingsBulkUpdate($hash, "todo_output", $test_results->{todo_output} , 1);


	if ($test_results->{error}) {
		Log3 $name, 5, "$name/UnitTest_finished: return from eval was with error $@" ;
		{
			is ( $test_results->{error}, undef, 'Expecting Test to exit without errors' );
			
		}
		readingsBulkUpdate($hash, "state", "finished with error", 1);
		
	} else {
		readingsBulkUpdate($hash, "state", "finished", 1);
		
	}
	readingsEndUpdate($hash,1);

}

sub UnitTest_Test_generic
{
	
	# Define some generic vars for our Test
	my $hash = shift;	
	readingsSingleUpdate($hash, "state", "running", 1);
	Log3 $hash->{NAME}, 5, $hash->{NAME}."/UnitTest_Test_generic: starting test in subprocess" ;
	
	if (AttrVal($hash->{NAME},"fork",0) )
	{ 
		BlockingCall("UnitTest_run", $hash, "UnitTest_finished", 300,"UnitTest_aborted");
	} else {
		my $jsonReturn =UnitTest_run($hash);
		UnitTest_finished($jsonReturn);
		$hash->{test_output} =~ tr{\n}{ };
		$hash->{test_output} =~ s{\n}{\\n}g;
	}
    
}

#
# Demo code yust demonstrating how test code is written
# Verify if the given device is a signalduino and if it is opened
#


sub UnitTest_Test_1
{
	my ($own_hash) = @_;
	
	my $targetHash = $defs{$own_hash->{targetDevice}};
	#print Dumper($targetHash);
	
    is( $targetHash->{TYPE}, "SIGNALduino", 'SIGNALduino detected' );
    is( ReadingsVal($targetHash->{NAME},"state",""),"opened", 'SIGNALduino is opened' );


    # Bad tests, bevause the result depends on the time which is over till now
	#ok( keys %{$targetHash->{msIdList}} == 0, 'msIdList not yet initialized' );
	#ok( $targetHash->{muIdList} eq "SIGNALduino", 'SIGNALduino detected' );
	#ok( $targetHash->{mcIdList} eq "SIGNALduino", 'SIGNALduino detected' );
	
}


#
# Verify if the SIGNALDuino_Shutdown sub writes the correct chars to the serial port
#
sub UnitTest_Test_2
{
	use Test::Device::SerialPort;
	my ($own_hash) = @_;
	my $targetHash = $defs{$own_hash->{targetDevice}};

    ## Mock a dummy serial device
	my $PortObj = Test::Device::SerialPort->new('/dev/ttyS0');
	$PortObj->baudrate(57600);
    $PortObj->parity('none');
    $PortObj->databits(8);
    $PortObj->stopbits(1);
	$targetHash->{USBDev} = $PortObj;
	CallFn($targetHash->{NAME}, "ShutdownFn", $targetHash);
	
    is( $targetHash->{USBDev}->{_tx_buf}, "XQ\n", 'SIGNALDuino_Shutdown sends correct characters' );
    
    #cleanup
    $targetHash->{USBDev} = undef;
}

#
# Verify MS Decoder with NC_WS Data
# DMSG s5C080FC32000
# T: 25.2 H: 50


sub UnitTest_Test_3
{
	my ($own_hash) = @_;
	my $targetHash = $defs{$own_hash->{targetDevice}};
	
	my $Dispatch;
   	my $mock;
   	$mock = Mock::Sub->new; 
    $Dispatch = $mock->mock('Dispatch');
    
        		
    my $rmsg="MS;P1=502;P2=-9212;P3=-1939;P4=-3669;D=12131413141414131313131313141313131313131314141414141413131313141413131413;CP=1;SP=2;";
	my %signal_parts=SIGNALduino_Split_Message($rmsg,$targetHash->{NAME});   ## Split message and save anything in an hash %signal_parts
    SIGNALduino_Parse_MS($targetHash, $targetHash, $targetHash->{NAME}, $rmsg,%signal_parts);
    is($Dispatch->called_count, 1, "Called Dispatch from parse MS");
	
	if ($Dispatch->called_count){		
		my @called_args = $Dispatch->called_with;
		is( $called_args[1], "s5C080FC32000", 'Parse_MS dispatched message for Module CUL_TCM_97001' );
	}
	
}


sub UnitTest_mock_log3
{
	# Placeholder function for mocking a fhem sub
	
	my ($own_hash) = @_;
	
	my $mock = Mock::Sub->new;
 	my $Log = $mock->mock('Log3');
 	
    Log3 undef, 2, "test Message";


	$Log->name;         # name of sub that's mocked
	$Log->called;       # was the sub called?
	$Log->called_count; # how many times was it called?
	$Log->called_with;  # array of params sent to sub
	print Dumper($Log);
	
	
}

# Eval-Rückgabewert für erfolgreiches
# Laden des Moduls
1;


# Beginn der Commandref

=pod
=item [helper|device|command]
=item summary Helpermodule which supports unit tesing
=item summary_DE Hilfsmodul was es ermöglicht unit test auszuführen

=begin html

 <a name="UnitTest"></a>
 <h3>UnitTest</h3><br>
  
  The Module runs perl code (unit tests) which is specified in the definition. The code which is in braces will be evaluated.<br><br>
  <small><u><b>Necessary components PERL:</u></b></small> <ul>Mock::Sub Test::More & Test::More Test::Device::SerialPort <br>(install via <code>cpan Mock::Sub Test::More Test::Device::SerialPort</code> on system)</ul><br>
  <a name="UnitTestdefine"></a>
  <b>Define</b><br>
 
  <ul><code>define &lt;NameOfThisDefinition&gt; UnitTest &lt;Which device is under test&gt; ( { PERL CODE GOES HERE }  )</code></ul>
  
  <ul><u>example:</u><br>
  <code>define test1 UnitTest dummyDuino ( { Log3 undef, 2, "this is a Log Message inside our Test";; } )
  </code></ul><br>
  
  <b>Attribute</b><br>
	<ul><li><a name="disable"></a>disable<br>
		A UnitTest definition can be disabled with the attribute disable. If disabled, the perl code provided in the definition will not be executed. 
		The readings "test_output" and "test_failure" from this definition will be deleted. If you delete this attribute or setting it to 0, the test will start immediatly</li><a name=" "></a></ul><br>
  
  <a name="UnitTestinternals"></a>
  <b>Internals</b>
  <ul>
   <li> state - finished / waiting, Status of the current unittest (waiting, the test is running)
   <li> test_failure - Failures from our unittest will go in here
   <li> test_output - ok / nok Messages will be visible here
   <li> todo_output - diagnostics output of a todo test
  </ul><br><br>
  <a name="code_example"></a>
  <b>code example:</b><br>
  <ul>
  dummyDuino<br>
  &nbsp;&nbsp;(<br>
  &nbsp;&nbsp;&nbsp;&nbsp;{<br>
    
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;my $mock = Mock::Sub->new;<br>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;my $Log3= $mock->mock("SIGNALduino_Log3");<br>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SIGNALduino_IdList("x:$target","","","");<br>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;my $ref_called_count = $Log3->called_count;<br><br>
    
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;my $id = 9999;<br>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$main::ProtocolListSIGNALduino{$id} =
        {
            name			=> 'test protocol',		
			comment			=> 'none' ,
			id          	=> '9999',
			developId		=> 'm',
	 },<br>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SIGNALduino_IdList("x:$target","","","m9999");<br>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;is($Log3->called_count-$ref_called_count,$ref_called_count+1,"SIGNALduino_Log3 output increased");})
  </ul><br>
  <a href="https://github.com/fhem/UnitTest/blob/master/install.md">Other instructions can be found here.</a>
=end html


=begin html_DE

 <a name="UnitTest"></a>
 <h3>UnitTest</h3><br>
  
  Das Modul f&uuml;hrt einen Perl-Code (unit tests) aus, der in der Definition festgelegt wird. Der Code in geschweiften Klammern wird ausgewertet.<br>
    <small><u><b>Ben&ouml;tigte Bestandteile PERL:</u></b></small> <ul>Mock::Sub Test::More & Test::More Test::Device::SerialPort <br>(install via <code>cpan Mock::Sub Test::More Test::Device::SerialPort</code> auf dem System)</ul><br>
  <a name="UnitTestdefine"></a>
  <b>Define</b><br>
 
  <ul><code>define &lt;NameDerDefinition&gt; UnitTest &lt;Which device is under test&gt; ( { PERL CODE GOES HERE }  )</code></ul>
  
  <ul><u>Beispiel:</u><br>
  <code>define test1 UnitTest dummyDuino ( { Log3 undef, 2, "this is a Log Message inside our Test";; } )
  </code></ul><br>
  
  <b>Attribute</b><br>
	<ul><li><a name="disable"></a>disable<br>
		Eine UnitTest Definition kann mit Hilfe des Attributes disable, deaktiviert werden. Damit wird verhindert, dass der Perl Code ausgef&uuml;hrt wird. 
		Es werden die Readings "test_output" und "test_failure" der Definition gel&ouml;scht. Wird das Attribut gel&ouml;scht oder auf 0 gesetzt, so wird der Tests umgehend ausgef&uuml;hrt.</li><a name=" "></a></ul><br>
    <a name="UnitTestinternals"></a>
  <b>Internals</b>
  <ul>
   <li> state - finished / waiting, Status des aktuellen Unittest (waiting, der Test l&auml;ft aktuell)
   <li> test_failure - Fehler aus unserem Unittest werden hier ausgegeben
   <li> test_output - ok / nok, Nachrichten werden hier sichtbar sein
   <li> todo_output - Diagnoseausgabe eines Todo-Tests
  </ul><br><br>
  <a name="Code_Beispiel"></a>
  <b>Code Beispiel:</b><br>
  <ul>
  dummyDuino<br>
  &nbsp;&nbsp;(<br>
  &nbsp;&nbsp;&nbsp;&nbsp;{<br>
    
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;my $mock = Mock::Sub->new;<br>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;my $Log3= $mock->mock("SIGNALduino_Log3");<br>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SIGNALduino_IdList("x:$target","","","");<br>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;my $ref_called_count = $Log3->called_count;<br><br>
    
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;my $id = 9999;<br>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$main::ProtocolListSIGNALduino{$id} =
        {
            name			=> 'test protocol',		
			comment			=> 'none' ,
			id          	=> '9999',
			developId		=> 'm',
	 },<br>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SIGNALduino_IdList("x:$target","","","m9999");<br>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;is($Log3->called_count-$ref_called_count,$ref_called_count+1,"SIGNALduino_Log3 output increased");})
  </ul><br>
  <a href="https://github.com/RFD-FHEM/UnitTest/blob/master/install.md">Eine weitere Anleitung finden Sie hier.</a>
=end html_DE

# Ende der Commandref
=cut
