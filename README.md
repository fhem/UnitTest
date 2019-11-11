UnitTest - FHEM Module
======


FHEM Module for developers who want to run unittests



How to install
======
The Perl modules can be loaded directly into your FHEM installation:

```update all https://raw.githubusercontent.com/RFD-FHEM/UnitTest/master/controls_unittest.txt```


### Writing my first unittest ### 
Define a new test with

defmod my_Test_1 UnitTest dummyDuino ({} ) 

Now you have a placeholder for defining your code.
Open the DEF from this device an put any perl code inside the {} brackets.

Note: the Name dummyDuino must be the name of a existing definition you want to run tests on. If you startet fhem with the provided minimal `fhem-ut.cfg`, then there is no Device of type SIGNALduino named dummyDuino. You can also use the Device WEB or global.

In your testcode you can run any perl command.

Additionally there are a few variables provided 

$hash = the hash of the UnitTest Definition
$name = The Name of the UnitTest Definition
$target = The Name of the provided Targetdevice which is under test. Provided in DEF from this UnitTest device. In our example dummyDuino.
$targetHash = Hash from the Targetdevice which is under test.


How To use this running automated unittests?
=====

Usage of the unitTest Module isn't very complex, but needs some basic understanding of unittests.

You can define UnitTests in files named <NameOfTest>-definition.txt
Inside this File you must name the definition <nameOfTest>:

An example can be found unter tests/test_modules-definition.txt

Because the unittest runs as a normal fhem operation the test and the code is defined as usaual for FHEM to apply perl code:

```
defmod test_modules UnitTest global (
 {
	my @modulesToTest=qw/98_DOIF.pm 98_DOIFtools.pm 33_readingsGroup.pm/; 
	
 	subtest 'Syntax Check Modules ' => sub {
		plan tests => scalar @modulesToTest;
		for my $module (@modulesToTest)
		{
			my $returncode = CommandReload(undef,$module);
			is($returncode, undef, "check $module ");
		};
	}; 

 };
);
```

Please avoid using double ";" in perlcode because this have special meanings when using test-runner.sh


What does this test do?
It is a very basic thing, it will verify the syntax of three modules; 98_DOIF.pm, 98_DOIFtools.pm and 33_readingsGroup.pm.
But be careful in combination with [Devel::Cover](https://metacpan.org/pod/Devel::Cover#Redefined-subroutines "Meta::cpan"), this test reloads the modules and causes a redefinment of all subs. So name such a test exactly "test_modules" and the makefile will run this test as the first one!

Variable recovery
=====
Just before starting the test, the hash of the definition under test is stored and recovered after the test.
So leving a test will restore the hash of the definition as it was before.

More Information
=====
Look at the source code of the module or some examples in the RFFHEM Repository where this module is used heavily

Advanced when using test-runner.sh
=====

Some advanced things can be done by providing multiple commands.
To seperate multile commands use double ";" as delemiter.

```
defmod devUnderTest dummy;;

defmod test_modules UnitTest devUnderTest (
 {
	1;
 };
);;

delete devUnderTest;;
```

This will call the commands in fhem
1. Create dummy devUnderTest
2. Run a test which will return simple 1
3. delete dummy devUnderTest
